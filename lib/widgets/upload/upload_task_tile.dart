import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/upload_task.dart';
import '../common/truncated_text.dart';
import '../file/file_icon.dart';

/// 上传队列里的一行任务。
///
/// 纯展示组件：只接收任务数据与操作回调，不依赖 UploadManager。
class UploadTaskTile extends StatelessWidget {
  final UploadTask task;

  /// 暂停（排队中 / 上传中）。
  final VoidCallback onPause;

  /// 继续或重试（已暂停 / 失败）。
  final VoidCallback onResume;

  /// 取消上传或删除记录（文案按状态决定）。
  final VoidCallback onRemove;

  const UploadTaskTile({
    super.key,
    required this.task,
    required this.onPause,
    required this.onResume,
    required this.onRemove,
  });

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
                          _TrailingAction(
                            task: task,
                            onPause: onPause,
                            onResume: onResume,
                            onRemove: onRemove,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TruncatedText(
                              text: _progressText(task),
                              style: TextStyle(
                                fontSize: 12,
                                color: context.appColors.textSecondary,
                              ),
                              detailTitle: task.status == UploadStatus.failed
                                  ? '上传失败详情'
                                  : null,
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
        final speed = task.speed > 0 ? '${formatSize(task.speed)}/s' : '--/s';
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

/// 任务行右侧的操作按钮，按状态切换。
class _TrailingAction extends StatelessWidget {
  final UploadTask task;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onRemove;

  const _TrailingAction({
    required this.task,
    required this.onPause,
    required this.onResume,
    required this.onRemove,
  });

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
              onPressed: onPause,
            ),
            IconButton(
              tooltip: '取消上传',
              icon: Icon(Icons.close, size: 20, color: color),
              onPressed: onRemove,
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
              onPressed: onResume,
            ),
            IconButton(
              tooltip: '取消上传',
              icon: Icon(Icons.close, size: 20, color: color),
              onPressed: onRemove,
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
              onPressed: onResume,
            ),
            IconButton(
              tooltip: '删除记录',
              icon: Icon(Icons.delete_outline, size: 20, color: color),
              onPressed: onRemove,
            ),
          ],
        );
      case UploadStatus.completed:
        return IconButton(
          tooltip: '删除记录',
          icon: Icon(Icons.delete_outline, size: 20, color: color),
          onPressed: onRemove,
        );
    }
  }
}
