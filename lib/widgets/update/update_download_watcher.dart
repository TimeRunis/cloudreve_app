import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/download_task.dart';
import '../../providers/download_provider.dart';
import '../../providers/update_provider.dart';
import 'update_flow.dart';

/// 监听更新安装包的下载任务：下载完成后弹出「立即安装」。
///
/// 挂在根部，不关心用户当前在哪个页面；只有确实发起过更新下载
/// （[UpdateState.taskId] 非空）时才订阅下载队列，避免无谓地常驻
/// 下载管理器。
class UpdateDownloadWatcher extends ConsumerStatefulWidget {
  final Widget child;

  const UpdateDownloadWatcher({super.key, required this.child});

  @override
  ConsumerState<UpdateDownloadWatcher> createState() =>
      _UpdateDownloadWatcherState();
}

class _UpdateDownloadWatcherState extends ConsumerState<UpdateDownloadWatcher> {
  /// 已经弹过安装提示的任务 id。
  String? _promptedTaskId;

  @override
  Widget build(BuildContext context) {
    final taskId = ref.watch(updateProvider.select((state) => state.taskId));
    if (taskId != null) {
      ref.listen<DownloadManagerState>(downloadManagerProvider, (_, next) {
        _checkCompleted(taskId, next.manager.tasks);
      });
      // 订阅那一刻可能已经下载完（小文件 / 复用已有任务）。
      _checkCompleted(taskId, ref.read(downloadManagerProvider).manager.tasks);
    }
    return widget.child;
  }

  void _checkCompleted(String taskId, List<DownloadTask> tasks) {
    if (_promptedTaskId == taskId) return;
    DownloadTask? completed;
    for (final task in tasks) {
      if (task.id == taskId) {
        if (task.status == DownloadStatus.completed) completed = task;
        break;
      }
    }
    if (completed == null) return;
    _promptedTaskId = taskId;
    final task = completed;
    final version = ref.read(updateProvider).release?.versionLabel;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      UpdateFlow.promptInstall(context, task, version: version);
    });
  }
}
