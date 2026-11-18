import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/download/download_manager.dart';
import '../core/log/app_log.dart';
import '../core/update/update_interval.dart';
import '../core/update/update_service.dart';
import '../models/app_release.dart';
import '../models/download_task.dart';
import 'api_provider.dart';
import 'download_provider.dart';
import 'storage_provider.dart';

/// 检查更新状态。
enum UpdateCheckStatus {
  /// 还没检查过。
  idle,

  /// 正在请求远端版本信息。
  checking,

  /// 已是最新版本。
  upToDate,

  /// 发现新版本。
  available,

  /// 检查失败（网络 / 限流等）。
  failed,
}

/// 检查更新的状态与结果。
class UpdateState {
  final UpdateCheckStatus status;

  /// 远端最新发布（检查成功后保留）。
  final AppRelease? release;

  /// 失败原因。
  final String? error;

  /// 正在下载更新包的下载任务 id（用于下载完成后提示安装）。
  final String? taskId;

  /// 已安装版本（`versionName`）。
  final String? installedVersion;

  /// 上次成功检查的时间。
  final DateTime? lastCheckAt;

  const UpdateState({
    this.status = UpdateCheckStatus.idle,
    this.release,
    this.error,
    this.taskId,
    this.installedVersion,
    this.lastCheckAt,
  });

  UpdateState copyWith({
    UpdateCheckStatus? status,
    AppRelease? release,
    String? error,
    String? taskId,
    String? installedVersion,
    DateTime? lastCheckAt,
    bool clearError = false,
  }) =>
      UpdateState(
        status: status ?? this.status,
        release: release ?? this.release,
        error: clearError ? null : (error ?? this.error),
        taskId: taskId ?? this.taskId,
        installedVersion: installedVersion ?? this.installedVersion,
        lastCheckAt: lastCheckAt ?? this.lastCheckAt,
      );
}

/// 检查更新服务（数据源固定为 GitHub Releases）。
final updateServiceProvider = Provider<UpdateService>(
  (ref) => UpdateService(dio: ref.watch(dioProvider)),
);

/// 更新检查与下载入口。
final updateProvider =
    NotifierProvider<UpdateNotifier, UpdateState>(UpdateNotifier.new);

class UpdateNotifier extends Notifier<UpdateState> {
  /// 同一次检查的并发去重（启动检查和设置页手动检查可能撞在一起）。
  Future<AppRelease?>? _inflight;

  /// 本进程内是否已经检查过（「每次启动」频率用）。
  bool _checkedThisLaunch = false;

  /// 本进程内上次发起检查的时间：失败后避免回到前台就疯狂重试。
  DateTime? _lastAttemptAt;

  /// 本次运行已经弹过窗的版本，避免同一版本反复打扰。
  final Set<String> _promptedTags = {};

  /// 已安装版本缓存。
  AppVersion _installed = const AppVersion(
    major: 0,
    minor: 0,
    patch: 0,
    prerelease: [],
    raw: '0.0.0',
  );

  @override
  UpdateState build() => UpdateState(
        lastCheckAt: ref.read(storageProvider).getUpdateLastCheckAt(),
      );

  // ---------- 查询 ----------

  /// 按 [interval] 判断本次启动 / 回到前台是否需要检查。
  bool isDue(UpdateCheckInterval interval) {
    if (state.status == UpdateCheckStatus.checking) return false;
    final now = DateTime.now();
    final attempt = _lastAttemptAt;
    if (attempt != null &&
        now.difference(attempt) < const Duration(minutes: 2)) {
      return false;
    }
    final gap = interval.minGap;
    if (gap == null) return !_checkedThisLaunch;
    final last = state.lastCheckAt;
    if (last == null) return true;
    return now.difference(last) >= gap;
  }

  /// 该版本本次运行是否已经弹过更新窗。
  bool wasPrompted(AppRelease release) => _promptedTags.contains(release.tag);

  void markPrompted(AppRelease release) => _promptedTags.add(release.tag);

  /// 当前安装包版本号。
  String get installedVersion => state.installedVersion ?? _installed.raw;

  // ---------- 检查 ----------

  /// 发起一次检查；有新版本时返回它，否则返回 null。
  Future<AppRelease?> check() {
    final inflight = _inflight;
    if (inflight != null) return inflight;
    final future = _runCheck();
    _inflight = future;
    future.whenComplete(() {
      if (identical(_inflight, future)) _inflight = null;
    });
    return future;
  }

  Future<AppRelease?> _runCheck() async {
    _checkedThisLaunch = true;
    _lastAttemptAt = DateTime.now();
    state =
        state.copyWith(status: UpdateCheckStatus.checking, clearError: true);

    final installed = await _loadInstalledVersion();
    try {
      final release = await ref.read(updateServiceProvider).fetchLatest();
      if (release == null) {
        state = state.copyWith(
          status: UpdateCheckStatus.failed,
          installedVersion: installed.raw,
          error: '未获取到发布信息',
        );
        return null;
      }
      final now = DateTime.now();
      state = state.copyWith(
        status: release.version.isNewerThan(installed)
            ? UpdateCheckStatus.available
            : UpdateCheckStatus.upToDate,
        release: release,
        installedVersion: installed.raw,
        lastCheckAt: now,
      );
      // 记录检查时间，供「每天 / 7 天 / 30 天」判断。
      try {
        await ref.read(storageProvider).setUpdateLastCheckAt(now);
      } catch (_) {
        // 写入失败不影响检查结果。
      }
      AppLogger.log.i('[Update] 当前 $installed，最新 ${release.versionLabel}');
      return release.version.isNewerThan(installed) ? release : null;
    } catch (e, stackTrace) {
      AppLogger.log.e('[Update] 检查更新失败', error: e, stackTrace: stackTrace);
      state = state.copyWith(
        status: UpdateCheckStatus.failed,
        installedVersion: installed.raw,
        error: _describeError(e),
      );
      return null;
    }
  }

  Future<AppVersion> _loadInstalledVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final parsed = AppVersion.tryParse(info.version);
      if (parsed != null) _installed = parsed;
    } catch (e) {
      AppLogger.log.w('[Update] 读取应用版本失败：$e');
    }
    return _installed;
  }

  String _describeError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '').trim();
    if (text.isEmpty) return '网络异常';
    return text.length > 80 ? '${text.substring(0, 80)}…' : text;
  }

  // ---------- 下载 ----------

  /// 把更新包加入全局下载队列（复用下载页的队列与进度）。
  ///
  /// 已经在队列里（或已下载完）的同一个包会直接复用，不会重复下载。
  Future<DownloadTask?> download(AppRelease release) async {
    final url = release.downloadUrl;
    if (url == null || url.isEmpty) return null;
    final manager = ref.read(downloadManagerProvider).manager;
    final name = release.assetName ?? 'cloudreve-${release.version.raw}.apk';

    DownloadTask? existing;
    for (final task in manager.tasks) {
      if (task.url == url) {
        existing = task;
        break;
      }
    }
    if (existing != null) {
      final id = existing.id;
      if (existing.status == DownloadStatus.paused ||
          existing.status == DownloadStatus.failed) {
        await manager.resume(id);
      }
      state = state.copyWith(taskId: id);
      return _taskById(manager, id);
    }

    try {
      final task = await manager.enqueue(
        fileId: '',
        uri: '',
        name: name,
        url: url,
        size: release.size ?? 0,
      );
      state = state.copyWith(taskId: task.id);
      AppLogger.log.i('[Update] 更新包已加入下载队列：${task.savePath}');
      return task;
    } catch (e, stackTrace) {
      AppLogger.log.e('[Update] 加入下载队列失败', error: e, stackTrace: stackTrace);
      state = state.copyWith(error: '加入下载队列失败：${_describeError(e)}');
      return null;
    }
  }

  DownloadTask? _taskById(DownloadManager manager, String id) {
    for (final task in manager.tasks) {
      if (task.id == id) return task;
    }
    return null;
  }
}
