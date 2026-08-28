import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import '../../models/upload_task.dart';
import '../wake_lock.dart';
import '../network/cloudreve_api.dart';
import '../storage/app_storage.dart';
import 'upload_notifications.dart';
import 'upload_strategy.dart';

typedef UploadApiProvider = CloudreveApi Function();

/// 全局上传队列管理器。
///
/// - 选择本地文件后创建 Cloudreve v4 上传会话，再按顺序上传分片。
/// - 任务与会话信息持久化到本地；重启或断网后如果会话未过期，
///   会从已成功上传的下一个分片继续（断点续传）。
/// - 支持暂停 / 恢复 / 删除 / 重试失败任务。
class UploadManager extends ChangeNotifier with WidgetsBindingObserver {
  UploadManager({
    required this.storage,
    required this.apiOf,
    List<UploadStrategy>? strategies,
  }) : _strategies = strategies ??
            [
              LocalUploadStrategy(),
              OneDriveUploadStrategy(),
              RemoteChunkUploadStrategy(),
            ];

  /// 同时上传的任务数。
  static const int maxConcurrentUploads = 2;

  final AppStorage storage;
  final UploadApiProvider apiOf;
  final List<UploadStrategy> _strategies;

  final List<UploadTask> _tasks = [];
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, int> _lastBytes = {};
  Timer? _ticker;
  bool _disposed = false;
  bool _overwrite = false;

  List<UploadTask> get tasks => List.unmodifiable(_tasks);

  int get activeCount =>
      _tasks.where((t) => t.isActive).length;

  int get uploadingCount =>
      _tasks.where((t) => t.status == UploadStatus.uploading).length;

  int get completedCount =>
      _tasks.where((t) => t.status == UploadStatus.completed).length;

  int get failedCount =>
      _tasks.where((t) => t.status == UploadStatus.failed).length;

  int get totalSpeed =>
      _tasks.fold(0, (sum, t) => sum + t.speed);

  bool get overwrite => _overwrite;

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    // 重启后把进行中/排队中的任务转为暂停，由用户手动继续。
    final saved = storage.getUploadTasks();
    _tasks.addAll(saved.map((t) => t.isActive
        ? t.copyWith(status: UploadStatus.paused, speed: 0, clearError: true)
        : t.copyWith(speed: 0)));
    notifyListeners();
    _schedule();
    _updateWakeLock();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _cancelTokens.clear();
    AppWakeLock.release('upload');
    UploadNotifications.stopService();
    try {
      storage.saveUploadTasks(_tasks);
    } catch (_) {}
    super.dispose();
  }

  /// App 回到前台：自动重试因后台 / 网络中断而失败的上传任务。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _retryFailedOnForeground();
    }
  }

  void _retryFailedOnForeground() {
    if (_disposed) return;
    var changed = false;
    for (var i = 0; i < _tasks.length; i++) {
      if (_tasks[i].status == UploadStatus.failed) {
        _tasks[i] =
            _tasks[i].copyWith(status: UploadStatus.waiting, clearError: true);
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
      _persist();
      _schedule();
      _updateWakeLock();
    }
  }

  // ---------- 对外操作 ----------

  /// 把一个或多个本地文件加入上传队列。
  Future<int> enqueueFiles({
    required List<String> paths,
    required String siteId,
    required String targetDirUri,
  }) async {
    var added = 0;
    for (final path in paths) {
      final file = File(path);
      if (!await file.exists()) continue;
      final stat = await file.stat();
      final name = path.split(Platform.pathSeparator).last;
      final task = UploadTask(
        id: UploadTask.newId(),
        siteId: siteId,
        localPath: path,
        fileName: name,
        targetDirUri: targetDirUri,
        targetUri: buildTargetFileUri(targetDirUri, name),
        totalSize: stat.size,
        lastModified: stat.modified.millisecondsSinceEpoch,
        uploadedBytes: 0,
        speed: 0,
        status: UploadStatus.waiting,
        chunkSize: 0,
        expires: 0,
        uploadedChunks: 0,
        createdAt: DateTime.now(),
      );
      _tasks.add(task);
      added++;
    }
    if (added > 0) {
      notifyListeners();
      await _persist();
      _schedule();
      _updateWakeLock();
    }
    return added;
  }

  void pause(String id) {
    final task = _byId(id);
    if (task == null || !task.isActive) return;
    _cancelTokens[id]?.cancel();
    _updateTask(task.copyWith(status: UploadStatus.paused, speed: 0));
    _persist();
    _updateWakeLock();
  }

  void resume(String id) {
    final task = _byId(id);
    if (task == null ||
        (task.status != UploadStatus.paused &&
            task.status != UploadStatus.failed)) {
      return;
    }
    _updateTask(task.copyWith(status: UploadStatus.waiting, clearError: true));
    _persist();
    _schedule();
    _updateWakeLock();
  }

  Future<void> remove(String id) async {
    final task = _byId(id);
    if (task == null) return;
    _cancelTokens[id]?.cancel();
    if (task.sessionId != null &&
        task.sessionId!.isNotEmpty &&
        task.status != UploadStatus.completed) {
      try {
        final api = apiOf();
        await api.deleteUploadSession(id: task.sessionId!, uri: task.targetUri);
      } catch (_) {
        // 删除会话失败不阻塞本地移除。
      }
    }
    _tasks.removeWhere((t) => t.id == id);
    _lastBytes.remove(id);
    notifyListeners();
    await _persist();
    _updateWakeLock();
  }

  void clearCompleted() {
    _tasks.removeWhere((t) => t.status == UploadStatus.completed);
    notifyListeners();
    _persist();
    _updateWakeLock();
  }

  void retryAllFailed() {
    var changed = false;
    for (var i = 0; i < _tasks.length; i++) {
      if (_tasks[i].status == UploadStatus.failed) {
        _tasks[i] =
            _tasks[i].copyWith(status: UploadStatus.waiting, clearError: true);
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
      _persist();
      _schedule();
      _updateWakeLock();
    }
  }

  void setOverwrite(bool value) {
    if (_overwrite == value) return;
    _overwrite = value;
    notifyListeners();
  }

  // ---------- 调度 ----------

  void _schedule() {
    if (_disposed) return;
    var running = _tasks
        .where((t) => t.status == UploadStatus.uploading)
        .length;
    for (final task in _tasks) {
      if (task.status != UploadStatus.waiting) continue;
      // 只上传属于当前站点的任务，避免切换站点后传到错误位置。
      if (apiOf().site?.id != task.siteId) continue;
      if (running >= maxConcurrentUploads) break;
      running++;
      _startUpload(task);
    }
  }

  Future<void> _startUpload(UploadTask task) async {
    final id = task.id;
    _updateTask(
        task.copyWith(status: UploadStatus.uploading, speed: 0, clearError: true));
    _lastBytes[id] = task.uploadedBytes;
    _updateWakeLock();

    try {
      var current = _byId(id)!;

      // 没有可用会话，或旧会话已过期时重新创建会话。
      if (!_hasValidSession(current)) {
        final session = await _createSession(current);
        if (session.sessionId.isEmpty) {
          throw Exception('创建上传会话失败');
        }
        current = current.copyWith(
          sessionId: session.sessionId,
          chunkSize: session.chunkSize,
          expires: session.expires,
          uploadedChunks: 0,
          uploadedBytes: 0,
          uploadUrl: session.uploadUrls.isNotEmpty
              ? session.uploadUrls.first
              : '',
          credential: session.credential ?? '',
          storageType: session.storagePolicyType ?? '',
          relay: session.relay,
          callbackSecret: session.callbackSecret ?? '',
        );
        _updateTask(current);
        _lastBytes[id] = 0;
        await _persist();
      }

      // 选定并固化当前任务的上传策略，便于断点续传时复用。
      var strategy = _strategyFor(current);
      if (strategy == null) {
        throw Exception('没有适配的上传策略: ${current.storageType}');
      }
      if (current.strategyId != strategy.id) {
        current = current.copyWith(strategyId: strategy.id);
        _updateTask(current);
        await _persist();
      }

      final chunkSize =
          current.chunkSize <= 0 ? current.totalSize : current.chunkSize;
      final totalChunks = current.totalSize <= 0
          ? 1
          : (chunkSize <= 0
              ? 1
              : (current.totalSize + chunkSize - 1) ~/ chunkSize);

      while (current.uploadedChunks < totalChunks) {
        current = _byId(id)!;
        if (current.status != UploadStatus.uploading) return;

        final index = current.uploadedChunks;
        final offset = index * chunkSize;
        final length = index == totalChunks - 1
            ? current.totalSize - offset
            : chunkSize;
        final bytes = await _readChunk(current.localPath, offset, length);
        final chunkBase = current.uploadedBytes;
        final chunkTotal = chunkBase + bytes.length;
        final cancelToken = CancelToken();
        _cancelTokens[id] = cancelToken;

        // 分片发送过程中实时更新 uploadedBytes，UI 进度条和速度不再等整个分片结束。
        var sentAll = false;
        void onSendProgress(int sent, int total) {
          if (total > 0 && sent >= total) sentAll = true;
          final live = _byId(id);
          if (live == null ||
              live.status != UploadStatus.uploading ||
              live.uploadedChunks != index) {
            return;
          }
          final nextBytes = (chunkBase + sent).clamp(0, chunkTotal);
          if (nextBytes == live.uploadedBytes) return;
          _updateTask(live.copyWith(uploadedBytes: nextBytes.toInt()));
        }

        try {
          // OneDrive 有时在上传进度到达 100% 后连接被服务端提前关闭，抛 Dio 错误；
          // 此时数据实际已完整发出，重试同一分片通常立即成功，因此自动重试几次。
          const maxUploadRetries = 3;
          final isOneDrive = current.strategyId == 'onedrive' ||
              current.storageType == 'onedrive';
          for (var attempt = 0; ; attempt++) {
            sentAll = false;
            try {
              await strategy.uploadChunk(
                api: apiOf(),
                task: current,
                index: index,
                bytes: bytes,
                chunkSize: chunkSize,
                cancelToken: cancelToken,
                onSendProgress: onSendProgress,
              );
              break;
            } on DioException catch (e) {
              if (CancelToken.isCancel(e)) return;
              if (isOneDrive &&
                  sentAll &&
                  attempt < maxUploadRetries - 1) {
                print('[UploadManager] OneDrive 分片 $index 发送到 100% 后连接异常，'
                    '自动重试第 ${attempt + 1} 次');
                continue;
              }
              rethrow;
            }
          }
        } finally {
          _cancelTokens.remove(id);
        }

        current = _byId(id)!;
        if (current.status != UploadStatus.uploading) return;

        // 分片完成时以精确值落盘，避免 onSendProgress 带来的中间值误差累积。
        _updateTask(current.copyWith(
          uploadedChunks: index + 1,
          uploadedBytes: chunkTotal,
        ));
        await _persist();
      }

      current = _byId(id)!;
      if (current.status == UploadStatus.uploading) {
        final completeStrategy = _strategyFor(current) ?? strategy;
        await completeStrategy.completeUpload(
          api: apiOf(),
          task: current,
        );
        current = _byId(id)!;
      }
      if (current.status == UploadStatus.uploading) {
        _updateTask(current.copyWith(
          status: UploadStatus.completed,
          uploadedBytes: current.totalSize,
          speed: 0,
        ));
        await _persist();
      }
    } catch (e) {
      final current = _byId(id);
      if (current != null && current.status == UploadStatus.uploading) {
        _updateTask(current.copyWith(
          status: UploadStatus.failed,
          speed: 0,
          error: e.toString(),
        ));
        await _persist();
      }
    } finally {
      _lastBytes.remove(id);
      _schedule();
      _updateWakeLock();
    }
  }

  Future<UploadSession> _createSession(UploadTask task) async {
    return apiOf().createUploadSession(
      uri: task.targetUri,
      size: task.totalSize,
      lastModified: task.lastModified,
      entityType: _overwrite ? 'version' : null,
    );
  }

  UploadStrategy? _strategyFor(UploadTask task) {
    // 优先使用持久化时记录的策略 id。
    if (task.strategyId.isNotEmpty) {
      for (final strategy in _strategies) {
        if (strategy.id == task.strategyId && strategy.canHandle(task)) {
          return strategy;
        }
      }
    }
    // 否则按当前会话信息自动匹配。
    for (final strategy in _strategies) {
      if (strategy.canHandle(task)) return strategy;
    }
    return null;
  }

  bool _hasValidSession(UploadTask task) {
    final id = task.sessionId;
    if (id == null || id.isEmpty || task.expires <= 0) return false;
    return DateTime.now().millisecondsSinceEpoch < task.expires * 1000;
  }

  Future<List<int>> _readChunk(
      String localPath, int offset, int length) async {
    final file = File(localPath);
    final raf = await file.open();
    try {
      await raf.setPosition(offset);
      return await raf.read(length);
    } finally {
      await raf.close();
    }
  }

  UploadTask? _byId(String id) {
    for (final t in _tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  void _updateTask(UploadTask task) {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index < 0) return;
    _tasks[index] = task;
    notifyListeners();
  }

  /// 有上传任务时持有 wakelock 并启动前台服务：锁屏 / 后台下
  /// 进程保持前台优先级，网络不会被系统挂起。
  void _updateWakeLock() {
    if (_disposed) return;
    final hasUploading =
        _tasks.any((t) => t.status == UploadStatus.uploading);
    final hasWaiting =
        _tasks.any((t) => t.status == UploadStatus.waiting);
    if (hasUploading || hasWaiting) {
      AppWakeLock.acquire('upload');
      _notifyForegroundService(start: true);
    } else {
      AppWakeLock.release('upload');
      UploadNotifications.stopService();
    }
  }

  /// 汇总当前上传总进度，更新 / 启动前台服务通知。
  void _notifyForegroundService({required bool start}) {
    final uploading = _tasks
        .where((t) => t.status == UploadStatus.uploading)
        .toList();
    final waiting = _tasks
        .where((t) => t.status == UploadStatus.waiting)
        .toList();
    if (uploading.isEmpty && waiting.isEmpty) return;
    final total = uploading.fold<int>(0, (sum, t) => sum + t.totalSize);
    final done =
        uploading.fold<int>(0, (sum, t) => sum + t.uploadedBytes);
    final percent = total <= 0
        ? 0
        : (done / total * 100).round().clamp(0, 100).toInt();
    final title = uploading.isNotEmpty
        ? '正在上传 ${uploading.length} 个任务'
        : '${waiting.length} 个任务排队中';
    final text = total > 0
        ? '${_fmtBytes(done)} / ${_fmtBytes(total)} · $percent%'
            '${waiting.isNotEmpty ? ' · ${waiting.length} 个排队中' : ''}'
        : '${waiting.length} 个任务等待开始';
    if (start) {
      UploadNotifications.startService(
          title: title, text: text, percent: percent);
    } else {
      UploadNotifications.updateService(
          title: title, text: text, percent: percent);
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

  void _onTick() {
    for (final task in _tasks) {
      if (task.status != UploadStatus.uploading) continue;
      final previous = _lastBytes[task.id] ?? task.uploadedBytes;
      final speed = task.uploadedBytes - previous;
      _lastBytes[task.id] = task.uploadedBytes;
      if (task.speed != speed) {
        _updateTask(task.copyWith(speed: speed));
      }
    }
    if (_tasks.any((t) => t.status == UploadStatus.uploading)) {
      _notifyForegroundService(start: false);
    }
  }

  Future<void> _persist() async {
    try {
      await storage.saveUploadTasks(_tasks);
    } catch (_) {}
  }
}