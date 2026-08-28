import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/upload/upload_manager.dart';
import '../models/upload_task.dart';
import '../providers/settings_provider.dart';
import '../providers/upload_provider.dart';
import '../widgets/file_icon.dart';

/// 上传队列页面。
///
/// 外观参考 docs/style/10.html 与 11.html 的上传队列窗口：
/// 顶部为「上传队列」标题栏，任务行包含文件图标、文件名和
/// 「速度 / 已上传 / 总大小 / 百分比」进度文案。
class UploadQueuePage extends ConsumerStatefulWidget {
  /// 点击「+」继续添加文件时上传到的目标目录 URI。
  final String targetDirUri;

  const UploadQueuePage({super.key, required this.targetDirUri});

  @override
  ConsumerState<UploadQueuePage> createState() => _UploadQueuePageState();
}

class _UploadQueuePageState extends ConsumerState<UploadQueuePage> {
  bool _hideCompleted = false;

  @override
  Widget build(BuildContext context) {
    final manager = ref.read(uploadManagerProvider).manager;

    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        final all = manager.tasks;
        final tasks = _hideCompleted
            ? all.where((t) => t.status != UploadStatus.completed).toList()
            : all;

        return Scaffold(
          backgroundColor: context.appColors.contentBg,
          appBar: AppBar(
            backgroundColor: context.appColors.headerBg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              tooltip: '返回',
              icon: Icon(Icons.close,
                  size: 18, color: context.appColors.textSecondary),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              '上传队列',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: context.appColors.textPrimary,
              ),
            ),
            actions: [
              IconButton(
                tooltip: '添加文件',
                icon: Icon(Icons.add,
                    size: 20, color: context.appColors.textSecondary),
                onPressed: _pickFiles,
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz,
                    color: context.appColors.textSecondary),
                color: context.appColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(color: context.appColors.border),
                ),
                onSelected: _handleMenu,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'overwrite',
                    child: Row(
                      children: [
                        Expanded(child: Text('覆盖已有文件')),
                        if (manager.overwrite)
                          Icon(Icons.check,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'hide_completed',
                    child: Row(
                      children: [
                        Expanded(child: Text('隐藏已完成任务')),
                        if (_hideCompleted)
                          Icon(Icons.check,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'retry_all', child: Text('重试所有失败任务')),
                  const PopupMenuItem(value: 'clear_completed', child: Text('清除已完成任务')),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: tasks.isEmpty
              ? _EmptyView()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) =>
                      _UploadTaskTile(task: tasks[index], manager: manager),
                ),
        );
      },
    );
  }

  Future<void> _pickFiles() async {
    final result =
        await FilePicker.platform.pickFiles(allowMultiple: true, withData: false);
    if (result == null || !mounted) return;
    final paths = result.files.map((f) => f.path).whereType<String>().toList();
    if (paths.isEmpty) return;
    final site = ref.read(currentSiteProvider);
    if (site == null) return;
    await ref
        .read(uploadManagerProvider)
        .manager
        .enqueueFiles(paths: paths, siteId: site.id, targetDirUri: widget.targetDirUri);
  }

  void _handleMenu(String value) {
    final manager = ref.read(uploadManagerProvider).manager;
    switch (value) {
      case 'overwrite':
        manager.setOverwrite(!manager.overwrite);
        break;
      case 'hide_completed':
        setState(() => _hideCompleted = !_hideCompleted);
        break;
      case 'retry_all':
        manager.retryAllFailed();
        break;
      case 'clear_completed':
        manager.clearCompleted();
        break;
    }
  }
}

class _UploadTaskTile extends StatelessWidget {
  final UploadTask task;
  final UploadManager manager;

  const _UploadTaskTile({required this.task, required this.manager});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = task.status == UploadStatus.completed;
    final progressColor = isCompleted
        ? Colors.green.withAlpha(32)
        : theme.colorScheme.primary.withAlpha(24);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fillWidth = constraints.maxWidth * task.progress;
          return Container(
            decoration: BoxDecoration(
              color: context.appColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.appColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: fillWidth,
                      color: progressColor,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDAE8FC),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              fileIconForName(task.fileName),
                              size: 24,
                              color: _fileColor(task.fileName),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              task.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: context.appColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          _TrailingAction(task: task, manager: manager),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _progressText(task),
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.appColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(task.progress * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isCompleted
                                  ? Colors.green.shade700
                                  : theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _progressText(UploadTask task) {
    switch (task.status) {
      case UploadStatus.waiting:
        return '排队中 · ${formatSize(task.uploadedBytes)} / '
            '${formatSize(task.totalSize)}';
      case UploadStatus.uploading:
        final speed = task.speed > 0
            ? '${formatSize(task.speed)}/s'
            : '--/s';
        return '$speed · ${formatSize(task.uploadedBytes)} / '
            '${formatSize(task.totalSize)}';
      case UploadStatus.paused:
        return '已暂停 · ${formatSize(task.uploadedBytes)} / '
            '${formatSize(task.totalSize)}';
      case UploadStatus.completed:
        return '已完成 · ${formatSize(task.totalSize)}';
      case UploadStatus.failed:
        return '上传失败：${task.error ?? '未知错误'}';
    }
  }

  Color _fileColor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        _isImageName(lower)) {
      return const Color(0xFFD50000);
    }
    if (lower.endsWith('.mp3') ||
        lower.endsWith('.flac') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.m4a')) {
      return const Color(0xFF651FFF);
    }
    return const Color(0xFF5F6368);
  }

  bool _isImageName(String lower) =>
      lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.bmp') ||
      lower.endsWith('.heic') ||
      lower.endsWith('.heif');
}

class _TrailingAction extends StatelessWidget {
  final UploadTask task;
  final UploadManager manager;

  const _TrailingAction({required this.task, required this.manager});

  @override
  Widget build(BuildContext context) {
    final color = context.appColors.textSecondary;
    switch (task.status) {
      case UploadStatus.waiting:
      case UploadStatus.uploading:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: '暂停',
              icon: Icon(Icons.pause, size: 20, color: color),
              onPressed: () => manager.pause(task.id),
            ),
            IconButton(
              tooltip: '取消上传',
              icon: Icon(Icons.close, size: 20, color: color),
              onPressed: () => manager.remove(task.id),
            ),
          ],
        );
      case UploadStatus.paused:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: '继续',
              icon: Icon(Icons.play_arrow, size: 20, color: color),
              onPressed: () => manager.resume(task.id),
            ),
            IconButton(
              tooltip: '取消上传',
              icon: Icon(Icons.close, size: 20, color: color),
              onPressed: () => manager.remove(task.id),
            ),
          ],
        );
      case UploadStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: '重试',
              icon: Icon(Icons.refresh, size: 20, color: color),
              onPressed: () => manager.resume(task.id),
            ),
            IconButton(
              tooltip: '删除记录',
              icon: Icon(Icons.delete_outline, size: 20, color: color),
              onPressed: () => manager.remove(task.id),
            ),
          ],
        );
      case UploadStatus.completed:
        return IconButton(
          tooltip: '删除记录',
          icon: Icon(Icons.delete_outline, size: 20, color: color),
          onPressed: () => manager.remove(task.id),
        );
    }
  }
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_upload_outlined,
              size: 48, color: context.appColors.textMuted),
          const SizedBox(height: 8),
          Text('暂无上传任务',
              style: TextStyle(
                  fontSize: 14, color: context.appColors.textSecondary)),
        ],
      ),
    );
  }
}