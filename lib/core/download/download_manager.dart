import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../models/download_task.dart';
import '../../models/file_item.dart';
import '../network/cloudreve_api.dart';
import '../storage/app_storage.dart';
import 'download_notifications.dart';

/// 下载相关设置（由设置页实时提供）。
class DownloadSettings {
  final bool multiThread;
  final int threadCount;

  const DownloadSettings({
    required this.multiThread,
    required this.threadCount,
  });
}

/// 按文件 URI 重新获取下载直链（失败重试时使用），需返回绝对地址。
typedef DownloadUrlFetcher = Future<String?> Function(String uri);

/// 全局下载队列管理器。
///
/// - 任务排队与并发调度（同时最多 [maxConcurrentTasks] 个）。
/// - 单线程断点续传；开启多线程时按 HTTP Range 分片并行下载。
/// - 任务列表持久化到本地，重启后恢复为「已暂停」，可继续下载。
/// - 下载期间持有 wakelock，锁屏后 CPU 不休眠，避免下载被挂起。
/// - App 回到前台时自动把因锁屏/网络中断而失败的任务重新排队。
/// - 生命周期跟随 Provider（应用切后台、切换页面期间持续下载）。
class DownloadManager extends ChangeNotifier with WidgetsBindingObserver {
  DownloadManager({
    required this.storage,
    required this.settingsOf,
    required this.dio,
    this.urlFetcher,
  });

  /// 同时进行的最大任务数。
  static const int maxConcurrentTasks = 3;

  /// 分片最小尺寸：小于该值的文件不使用多线程。
  static const int minSegmentSize = 1024 * 1024;

  final AppStorage storage;
  final DownloadSettings Function() settingsOf;
  final Dio dio;
  final DownloadUrlFetcher? urlFetcher;

  final List<DownloadTask> _tasks = [];
  final Map<String, _ActiveDownload> _active = {};

  Timer? _ticker;
  Timer? _persistTimer;
  bool _disposed = false;
  Directory? _downloadDir;

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);

  int get activeCount =>
      _tasks.where((t) => t.isActive).length;

  int get downloadingCount =>
      _tasks.where((t) => t.status == DownloadStatus.downloading).length;

  int get totalSpeed =>
      _tasks.fold(0, (sum, t) => sum + t.speed);

  /// 实际使用的下载目录（公共目录不可写时自动回退应用目录）。
  String? get downloadDirPath => _downloadDir?.path;

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    _downloadDir = await _resolveDownloadDir();
    if (_disposed) return;
    // 重启后进行中的任务转为暂停，由用户手动继续。
    final saved = storage.getDownloadTasks();
    _tasks.addAll(saved.map((t) => t.isActive
        ? t.copyWith(status: DownloadStatus.paused, speed: 0, clearError: true)
        : t.copyWith(speed: 0)));
    notifyListeners();
    _schedule();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _persistTimer?.cancel();
    for (final active in _active.values) {
      active.cancel();
    }
    WakelockPlus.disable();
    DownloadNotifications.stopService();
    for (final task in _tasks) {
      if (task.isActive) {
        DownloadNotifications.cancel(_notificationId(task.id));
      }
    }
    try {
      storage.saveDownloadTasks(_tasks);
    } catch (_) {}
    super.dispose();
  }

  /// App 回到前台：自动重试因锁屏 / 后台网络中断而失败的任务。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _retryFailedOnForeground();
    }
  }

  void _retryFailedOnForeground() {
    if (_disposed) return;
    final failed = _tasks
        .where((t) => t.status == DownloadStatus.failed)
        .toList();
    if (failed.isEmpty) return;
    for (final task in failed) {
      _setStatus(task.id, DownloadStatus.waiting, clearError: true);
    }
    _schedule();
  }

  /// 有活动任务时持有 wakelock 并启动前台服务：锁屏 / 深度休眠下
  /// 进程保持前台优先级，网络不会被系统挂起。
  void _updateWakeLock() {
    if (_disposed) return;
    final hasPending =
        _tasks.any((t) => t.status == DownloadStatus.waiting);
    if (_active.isNotEmpty || hasPending) {
      WakelockPlus.enable();
      _notifyForegroundService(start: true);
    } else {
      WakelockPlus.disable();
      DownloadNotifications.stopService();
    }
  }

  /// 汇总当前下载总进度，更新 / 启动前台服务通知。
  void _notifyForegroundService({required bool start}) {
    final downloading = _tasks
        .where((t) => t.status == DownloadStatus.downloading)
        .toList();
    final waiting = _tasks
        .where((t) => t.status == DownloadStatus.waiting)
        .toList();
    if (downloading.isEmpty && waiting.isEmpty) return;
    final total =
        downloading.fold<int>(0, (sum, t) => sum + t.totalSize);
    final done =
        downloading.fold<int>(0, (sum, t) => sum + t.downloadedBytes);
    final percent = total <= 0
        ? 0
        : (done / total * 100).round().clamp(0, 100).toInt();
    final title = downloading.isNotEmpty
        ? '正在下载 ${downloading.length} 个任务'
        : '${waiting.length} 个任务排队中';
    final text = total > 0
        ? '${_fmtBytes(done)} / ${_fmtBytes(total)} · $percent%'
            '${waiting.isNotEmpty ? ' · ${waiting.length} 个排队中' : ''}'
        : '${waiting.length} 个任务等待开始';
    if (start) {
      DownloadNotifications.startService(
          title: title, text: text, percent: percent);
    } else {
      DownloadNotifications.updateService(
          title: title, text: text, percent: percent);
    }
  }

  // ---------- 目录与路径 ----------

  /// 优先系统公共下载目录 `Download/cloudreve`；不可写时回退应用专属目录。
  Future<Directory> _resolveDownloadDir() async {
    final candidates = <String>[];
    if (Platform.isAndroid) {
      candidates.add('/storage/emulated/0/Download/cloudreve');
    }
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        candidates.add('${downloads.path}/cloudreve');
      }
    } catch (_) {
      // 平台不支持时忽略。
    }

    for (final path in candidates) {
      final dir = Directory(path);
      try {
        await dir.create(recursive: true);
        final probe = File('${dir.path}/.write_test');
        await probe.writeAsString('ok');
        await probe.delete();
        return dir;
      } catch (_) {
        // 公共目录不可写（Android 分区存储等），尝试下一个 / 回退。
      }
    }

    try {
      final base = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      final dir = Directory('${base.path}/Download/cloudreve');
      await dir.create(recursive: true);
      return dir;
    } catch (_) {
      final base = await getApplicationDocumentsDirectory();
      final dir = Directory('${base.path}/Download/cloudreve');
      await dir.create(recursive: true);
      return dir;
    }
  }

  Future<Directory> _ensureDownloadDir() async {
    if (_downloadDir != null) return _downloadDir!;
    _downloadDir = await _resolveDownloadDir();
    return _downloadDir!;
  }

  /// 同名文件自动追加 (1)、(2)…
  Future<String> _uniqueSavePath(Directory dir, String name) async {
    final safeName = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    var candidate = '${dir.path}/$safeName';
    var index = 1;
    while (await File(candidate).exists() ||
        await File('$candidate.cldpart').exists()) {
      final dot = safeName.lastIndexOf('.');
      final base = dot > 0 ? safeName.substring(0, dot) : safeName;
      final ext = dot > 0 ? safeName.substring(dot) : '';
      candidate = '${dir.path}/$base($index)$ext';
      index++;
    }
    return candidate;
  }

  String _absoluteUrl(String url, String base) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    if (url.startsWith('/')) return '$b$url';
    return '$b/$url';
  }

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(0x7fffffff)}';

  // ---------- 入队 ----------

  /// 把 Cloudreve 文件批量加入下载队列（内部批量获取直链）。
  Future<int> enqueueCloudreveFiles(
      CloudreveApi api, List<FileItem> files) async {
    if (files.isEmpty) return 0;
    final uris = files.map((f) => f.path).toList();
    final urls = await api.getFileSourceUrls(uris);
    if (urls.isEmpty) return 0;
    final base = api.site?.normalizedBaseUrl ?? '';
    var added = 0;
    for (var i = 0; i < files.length && i < urls.length; i++) {
      final file = files[i];
      await enqueue(
        fileId: file.id,
        uri: file.path,
        name: file.name,
        url: _absoluteUrl(urls[i], base),
        size: file.size,
      );
      added++;
    }
    return added;
  }

  /// 加入一个下载任务并触发调度。
  Future<DownloadTask> enqueue({
    required String fileId,
    required String uri,
    required String name,
    required String url,
    required int size,
  }) async {
    final dir = await _ensureDownloadDir();
    final savePath = await _uniqueSavePath(dir, name);
    final task = DownloadTask(
      id: _newId(),
      fileId: fileId,
      uri: uri,
      name: name,
      url: url,
      totalSize: size,
      downloadedBytes: 0,
      speed: 0,
      status: DownloadStatus.waiting,
      threadCount: _threadCountFor(size),
      createdAt: DateTime.now(),
      savePath: savePath,
    );
    _tasks.insert(0, task);
    notifyListeners();
    _persistSoon();
    _schedule();
    return task;
  }

  int _threadCountFor(int size) {
    final settings = settingsOf();
    if (!settings.multiThread || size < minSegmentSize) return 1;
    return max(1, min(settings.threadCount, 16));
  }

  // ---------- 调度 ----------

  void _schedule() {
    if (_disposed || _active.length >= maxConcurrentTasks) return;
    final waiting = _tasks
        .where((t) => t.status == DownloadStatus.waiting)
        .toList();
    for (final task in waiting) {
      if (_disposed || _active.length >= maxConcurrentTasks) break;
      _start(task);
    }
  }

  Future<void> _start(DownloadTask task) async {
    if (_disposed || _active.containsKey(task.id)) return;
    final active = _ActiveDownload(task.id);
    _active[task.id] = active;
    _setStatus(task.id, DownloadStatus.downloading, clearError: true);
    _notifyProgress(task);
    _updateWakeLock();
    try {
      if (task.threadCount > 1) {
        await _runMultiThread(task, active);
      } else {
        await _runSingleThread(task, active);
      }
    } catch (e) {
      if (_taskById(task.id) != null && !active.removed) {
        _setStatus(
          task.id,
          DownloadStatus.failed,
          error: '下载异常：$e',
          downloadedBytes: active.currentBytes,
        );
      }
    } finally {
      if (!active.done.isCompleted) active.done.complete();
      _active.remove(task.id);
      _updateWakeLock();
      if (!active.removed && !_disposed) _schedule();
    }
  }

  // ---------- 单线程下载 ----------

  Future<void> _runSingleThread(
      DownloadTask task, _ActiveDownload active) async {
    final part = File(task.partPath);
    var downloaded = await _fileSize(part);
    active.currentBytes = downloaded;
    IOSink? sink;
    try {
      final resp = await dio.get<ResponseBody>(
        task.url,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Range': 'bytes=$downloaded-'},
          validateStatus: (s) =>
              s != null && (s == 200 || s == 206 || s == 416),
        ),
        cancelToken: active.token,
      );
      if (active.token.isCancelled) {
        _setStatus(task.id, DownloadStatus.paused,
            downloadedBytes: active.currentBytes);
        return;
      }
      if (resp.statusCode == 416) {
        // Range 无效且已有完整内容：视为完成。
        _updateTaskBytes(task.id, downloaded);
        await part.rename(task.savePath);
        _setStatus(task.id, DownloadStatus.completed,
            downloadedBytes: downloaded);
        return;
      }
      final body = resp.data;
      if (body == null) {
        _setStatus(task.id, DownloadStatus.failed, error: '服务器返回空响应');
        return;
      }
      if (resp.statusCode == 200 && downloaded > 0) {
        // 服务器不支持断点：从头下载。
        await part.delete();
        downloaded = 0;
        active.currentBytes = 0;
        _updateTaskBytes(task.id, 0);
      }
      sink = part.openWrite(mode: FileMode.append);
      var current = downloaded;
      await for (final chunk in body.stream) {
        if (active.token.isCancelled) break;
        sink.add(chunk);
        current += chunk.length;
        active.currentBytes = current;
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (active.token.isCancelled) {
        _setStatus(task.id, DownloadStatus.paused,
            downloadedBytes: current);
        return;
      }
      _updateTaskBytes(task.id, current);
      await part.rename(task.savePath);
      _setStatus(task.id, DownloadStatus.completed,
          downloadedBytes: current);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        _setStatus(task.id, DownloadStatus.paused,
            downloadedBytes: active.currentBytes);
      } else {
        _setStatus(task.id, DownloadStatus.failed,
            error: e.message ?? '网络错误',
            downloadedBytes: active.currentBytes);
      }
    } catch (e) {
      _setStatus(task.id, DownloadStatus.failed,
          error: e.toString(), downloadedBytes: active.currentBytes);
    } finally {
      try {
        await sink?.close();
      } catch (_) {}
    }
  }

  // ---------- 多线程下载 ----------

  Future<void> _runMultiThread(
      DownloadTask task, _ActiveDownload active) async {
    final part = File(task.partPath);
    final total = task.totalSize;
    final base = await _fileSize(part);
    active.baseBytes = base;
    active.currentBytes = base;
    if (total <= 0) {
      // 未知大小无法分片，降级单线程。
      await _runSingleThread(task, active);
      return;
    }
    if (base >= total) {
      await part.rename(task.savePath);
      _setStatus(task.id, DownloadStatus.completed, downloadedBytes: total);
      return;
    }

    final segments =
        _buildSegments(task, base, total, task.threadCount);
    final state = _MultiState();
    final results = await Future.wait(segments.map(
        (seg) => _downloadSegment(task, seg, segments, active, state)));
    for (var i = 0; i < segments.length && i < results.length; i++) {
      final result = results[i];
      if (!result.ok && !result.cancelled) {
        segments[i].failure = result.error ?? '分片下载失败';
      }
    }

    if (state.fallback) {
      // 服务器不支持 Range：清理分段后降级单线程从头下载。
      await _deleteSegments(segments);
      if (base > 0) {
        await _deleteIfExists(part);
      }
      active.baseBytes = 0;
      active.currentBytes = 0;
      active.token = CancelToken();
      await _runSingleThread(task, active);
      return;
    }

    if (active.token.isCancelled) {
      await _mergeSegments(segments, part);
      final merged = await _fileSize(part);
      _setStatus(task.id, DownloadStatus.paused, downloadedBytes: merged);
      return;
    }

    final failures = _segmentFailures(segments);
    if (failures.isNotEmpty) {
      await _mergeSegments(segments, part);
      final merged = await _fileSize(part);
      _setStatus(task.id, DownloadStatus.failed,
          error: failures.first, downloadedBytes: merged);
      return;
    }

    await _mergeSegments(segments, part);
    final merged = await _fileSize(part);
    if (merged >= total) {
      await part.rename(task.savePath);
      _setStatus(task.id, DownloadStatus.completed, downloadedBytes: merged);
    } else {
      _setStatus(task.id, DownloadStatus.failed,
          error: '下载不完整（$merged/$total）', downloadedBytes: merged);
    }
  }

  List<_Segment> _buildSegments(
      DownloadTask task, int start, int total, int threadCount) {
    final remaining = total - start;
    final count = max(1, min(threadCount, (remaining / minSegmentSize).ceil()));
    final size = (remaining / count).ceil();
    final segments = <_Segment>[];
    for (var i = 0; i < count; i++) {
      final segStart = start + i * size;
      if (segStart >= total) break;
      final segEnd = min(total - 1, segStart + size - 1);
      segments.add(_Segment(
        index: i,
        start: segStart,
        end: segEnd,
        length: segEnd - segStart + 1,
        partPath: task.segmentPartPath(i),
      ));
    }
    return segments;
  }

  Future<_SegmentResult> _downloadSegment(
    DownloadTask task,
    _Segment seg,
    List<_Segment> segments,
    _ActiveDownload active,
    _MultiState state,
  ) async {
    final file = File(seg.partPath);
    IOSink? sink;
    try {
      final resp = await dio.get<ResponseBody>(
        task.url,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Range': 'bytes=${seg.start}-${seg.end}'},
          validateStatus: (s) =>
              s != null && (s == 200 || s == 206 || s == 416),
        ),
        cancelToken: active.token,
      );
      if (resp.statusCode == 200) {
        state.fallback = true;
        active.cancel();
        return _SegmentResult(ok: false, cancelled: true);
      }
      if (resp.statusCode == 416) {
        return _SegmentResult(ok: true);
      }
      final body = resp.data;
      if (body == null) {
        return _SegmentResult(ok: false, error: '服务器返回空响应');
      }
      sink = file.openWrite(mode: FileMode.write);
      var bytes = 0;
      await for (final chunk in body.stream) {
        if (active.token.isCancelled || state.fallback) break;
        sink.add(chunk);
        bytes += chunk.length;
        seg.downloaded = bytes;
        active.currentBytes = active.baseBytes +
            segments.fold<int>(0, (sum, e) => sum + e.downloaded);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (active.token.isCancelled || state.fallback) {
        return _SegmentResult(ok: false, cancelled: true);
      }
      if (bytes < seg.length) {
        return _SegmentResult(ok: false, error: '分片 ${seg.index + 1} 下载不完整');
      }
      return _SegmentResult(ok: true);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        return _SegmentResult(ok: false, cancelled: true);
      }
      return _SegmentResult(ok: false, error: e.message ?? '网络错误');
    } catch (e) {
      return _SegmentResult(ok: false, error: e.toString());
    } finally {
      try {
        await sink?.close();
      } catch (_) {}
    }
  }

  List<String> _segmentFailures(List<_Segment> segments) => [
        for (final seg in segments)
          if (seg.failure != null) seg.failure!,
      ];

  Future<void> _mergeSegments(
      List<_Segment> segments, File part) async {
    final sink = part.openWrite(mode: FileMode.append);
    try {
      for (final seg in segments) {
        final file = File(seg.partPath);
        if (!await file.exists()) break;
        await sink.addStream(file.openRead());
        await file.delete();
      }
    } finally {
      await sink.close();
    }
  }

  Future<void> _deleteSegments(List<_Segment> segments) async {
    for (final seg in segments) {
      await _deleteIfExists(File(seg.partPath));
    }
  }

  // ---------- 任务操作 ----------

  DownloadTask? _taskById(String id) {
    for (final t in _tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> pause(String id) async {
    final task = _taskById(id);
    if (task == null) return;
    if (task.status == DownloadStatus.waiting) {
      _setStatus(id, DownloadStatus.paused);
      return;
    }
    final active = _active[id];
    if (active != null) active.cancel();
  }

  Future<void> resume(String id) async {
    final task = _taskById(id);
    if (task == null) return;
    if (task.status != DownloadStatus.paused &&
        task.status != DownloadStatus.failed) {
      return;
    }
    // 先进入排队状态，让 UI 立即反馈；刷新直链在后台完成。
    _setStatus(id, DownloadStatus.waiting, clearError: true);
    if (task.status == DownloadStatus.failed &&
        task.uri.isNotEmpty &&
        urlFetcher != null) {
      try {
        final fresh = await urlFetcher!(task.uri);
        final index = _tasks.indexWhere((t) => t.id == id);
        if (fresh != null && fresh.isNotEmpty && index >= 0) {
          _tasks[index] = _tasks[index].copyWith(url: fresh);
        }
      } catch (_) {
        // 重新取链失败时仍用旧链接尝试一次。
      }
    }
    if (_taskById(id) == null) return;
    _schedule();
  }

  Future<void> pauseAll() async {
    for (final t in List<DownloadTask>.of(_tasks)) {
      if (t.status == DownloadStatus.downloading) {
        _active[t.id]?.cancel();
      } else if (t.status == DownloadStatus.waiting) {
        _setStatus(t.id, DownloadStatus.paused);
      }
    }
  }

  Future<void> resumeAll() async {
    for (final t in List<DownloadTask>.of(_tasks)) {
      if (t.status == DownloadStatus.paused ||
          t.status == DownloadStatus.failed) {
        _setStatus(t.id, DownloadStatus.waiting, clearError: true);
      }
    }
    _schedule();
  }

  /// 删除任务；[deleteFile] 为 true 时同时删除已下载文件与临时文件。
  Future<void> remove(String id, {bool deleteFile = true}) async {
    final task = _taskById(id);
    if (task == null) return;
    final active = _active[id];
    if (active != null) {
      active.removed = true;
      active.cancel();
    }
    // 先从列表移除并通知，保证按钮点击立即生效；文件清理异步收尾。
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
    _persistSoon();
    DownloadNotifications.cancel(_notificationId(id));
    _updateWakeLock();
    if (deleteFile) {
      if (active != null) {
        try {
          await active.done.future.timeout(const Duration(seconds: 5));
        } catch (_) {}
      }
      await _deleteIfExists(File(task.savePath));
      await _deleteIfExists(File(task.partPath));
      for (var i = 0; i < 16; i++) {
        await _deleteIfExists(File(task.segmentPartPath(i)));
      }
    }
  }

  /// 清空已完成记录（保留已下载文件）。
  Future<void> clearCompleted() async {
    _tasks.removeWhere((t) => t.status == DownloadStatus.completed);
    notifyListeners();
    _persistSoon();
  }

  // ---------- 状态与持久化 ----------

  void _setStatus(
    String id,
    DownloadStatus status, {
    String? error,
    bool clearError = false,
    int? downloadedBytes,
  }) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index < 0) return;
    final old = _tasks[index];
    _tasks[index] = old.copyWith(
      status: status,
      error: clearError ? null : error,
      clearError: clearError || error != null,
      downloadedBytes: downloadedBytes ?? old.downloadedBytes,
      speed: status == DownloadStatus.downloading ? old.speed : 0,
    );
    notifyListeners();
    _persistSoon();
    _notifyForStatus(_tasks[index]);
    _updateWakeLock();
  }

  void _updateTaskBytes(String id, int bytes) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index < 0) return;
    _tasks[index] = _tasks[index].copyWith(downloadedBytes: bytes);
    notifyListeners();
  }

  void _onTick() {
    if (_disposed) return;
    var changed = false;
    for (final active in _active.values) {
      final delta = active.currentBytes - active.lastTickBytes;
      active.lastTickBytes = active.currentBytes;
      final index = _tasks.indexWhere((t) => t.id == active.taskId);
      if (index >= 0) {
        final t = _tasks[index];
        if (t.status == DownloadStatus.downloading) {
          _tasks[index] =
              t.copyWith(downloadedBytes: active.currentBytes, speed: delta);
          changed = true;
          _notifyProgress(_tasks[index]);
        }
      }
    }
    if (changed) notifyListeners();
    if (_active.isNotEmpty) {
      _notifyForegroundService(start: false);
    }
    _persistSoon();
  }

  void _persistSoon() {
    if (_disposed) return;
    _persistTimer ??= Timer(const Duration(seconds: 2), () {
      _persistTimer = null;
      if (!_disposed) _persistNow();
    });
  }

  Future<void> _persistNow() async {
    if (_disposed) return;
    try {
      await storage.saveDownloadTasks(_tasks);
    } catch (_) {}
  }

  // ---------- 通知栏进度 ----------

  int _notificationId(String taskId) => taskId.hashCode & 0x7fffffff;

  void _notifyProgress(DownloadTask task) {
    final percent = (task.progress * 100).round();
    final speed = task.speed > 0 ? ' · ${_fmtBytes(task.speed)}/s' : '';
    DownloadNotifications.show(
      id: _notificationId(task.id),
      title: task.name,
      text: '${_fmtBytes(task.downloadedBytes)} / ${_fmtBytes(task.totalSize)}'
          ' · $percent%$speed',
      percent: percent,
    );
  }

  void _notifyForStatus(DownloadTask task) {
    final id = _notificationId(task.id);
    switch (task.status) {
      case DownloadStatus.waiting:
        DownloadNotifications.show(
          id: id,
          title: task.name,
          text: '排队中',
          percent: (task.progress * 100).round(),
        );
        break;
      case DownloadStatus.downloading:
        _notifyProgress(task);
        break;
      case DownloadStatus.paused:
        DownloadNotifications.finish(
            id: id, title: task.name, text: '已暂停');
        break;
      case DownloadStatus.completed:
        DownloadNotifications.finish(
            id: id,
            title: task.name,
            text: '下载完成 · ${_fmtBytes(task.totalSize)}');
        break;
      case DownloadStatus.failed:
        DownloadNotifications.finish(
            id: id,
            title: task.name,
            text: '下载失败${task.error == null ? '' : ' · ${task.error}'}');
        break;
    }
  }

  String _fmtBytes(int bytes) {
    if (bytes <= 0) return '0B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = bytes.toDouble();
    var i = 0;
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(size >= 100 ? 0 : 1)} ${units[i]}';
  }

  Future<int> _fileSize(File file) async {
    try {
      return await file.length();
    } catch (_) {
      return 0;
    }
  }

  Future<void> _deleteIfExists(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}

class _ActiveDownload {
  final String taskId;
  final Completer<void> done = Completer<void>();

  CancelToken token = CancelToken();
  bool removed = false;
  int currentBytes = 0;
  int lastTickBytes = 0;
  int baseBytes = 0;

  _ActiveDownload(this.taskId);

  void cancel() {
    if (!token.isCancelled) token.cancel();
  }
}

class _MultiState {
  bool fallback = false;
}

class _Segment {
  final int index;
  final int start;
  final int end;
  final int length;
  final String partPath;
  int downloaded = 0;
  String? failure;

  _Segment({
    required this.index,
    required this.start,
    required this.end,
    required this.length,
    required this.partPath,
  });
}

class _SegmentResult {
  final bool ok;
  final bool cancelled;
  final String? error;

  const _SegmentResult({required this.ok, this.cancelled = false, this.error});
}
