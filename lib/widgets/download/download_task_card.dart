import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/theme/app_colors.dart';
import '../../models/download_task.dart';
import '../file/file_icon.dart';
import 'download_detail_sheet.dart';
import 'download_style.dart';
import 'download_task_thumbnail.dart';
import '../../core/i18n/app_localizations.dart';

/// 删除动作的类型：是否同时删除已下载文件。
typedef DownloadTaskRemover = void Function({required bool deleteFile});

/// 下载任务卡片。
///
/// 纯展示组件：只接收任务数据与暂停/继续/删除回调，不依赖 DownloadManager。
class DownloadTaskCard extends StatelessWidget {
  final DownloadTask task;

  final VoidCallback onPause;

  /// 继续或重试。
  final VoidCallback onResume;

  /// 取消/删除，[deleteFile] 表示是否连文件一起删除。
  final DownloadTaskRemover onRemove;

  const DownloadTaskCard({
    super.key,
    required this.task,
    required this.onPause,
    required this.onResume,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final color = downloadStatusColor(context, task.status);
    final completed = task.status == DownloadStatus.completed;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DownloadTaskThumbnail(task: task),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.appColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            tr(task.statusLabel),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: context.appColors.textSecondary),
                          ),
                        ),
                        if (task.status == DownloadStatus.downloading) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '· ${formatSpeed(task.speed)}',
                                maxLines: 1,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: context.appColors.textSecondary),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      completed
                          ? formatSize(task.totalSize)
                          : '${formatSize(task.downloadedBytes)} / ${formatSize(task.totalSize)}'
                              ' · ${(task.progress * 100).toStringAsFixed(1)}%'
                              '${task.threadCount > 1 ? ' · ${task.threadCount}线程' : ''}',
                      style: TextStyle(
                          fontSize: 11, color: context.appColors.textMuted),
                    ),
                    if (task.status == DownloadStatus.failed &&
                        task.error != null &&
                        task.error!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        tr('失败原因：{error}', args: {'error': task.error ?? ''}),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => _showDetail(context),
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.info_outline,
                      size: 18, color: context.appColors.textMuted),
                ),
              ),
            ],
          ),
          if (!completed) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: task.progress,
                minHeight: 5,
                color: color,
                backgroundColor: context.appColors.surfaceMuted,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: _actions(context),
          ),
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context) {
    Widget button(String label, VoidCallback onTap, {Color? color}) {
      return TextButton(
        style: TextButton.styleFrom(
          foregroundColor: color ?? Theme.of(context).colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(56, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontSize: 13)),
      );
    }

    switch (task.status) {
      case DownloadStatus.downloading:
        return [
          button(tr('暂停'), onPause),
          button(
              tr('取消'),
              () => _confirmRemove(
                    context,
                    title: tr('取消任务'),
                    message: tr('将停止下载并删除已下载的文件与临时文件，此操作不可恢复。'),
                    actionLabel: tr('确定取消'),
                    deleteFile: true,
                  ),
              color: context.appColors.textSecondary),
        ];
      case DownloadStatus.waiting:
        return [
          button(
              tr('取消'),
              () => _confirmRemove(
                    context,
                    title: tr('取消任务'),
                    message: tr('将删除排队任务及其临时文件，此操作不可恢复。'),
                    actionLabel: tr('确定取消'),
                    deleteFile: true,
                  ),
              color: context.appColors.textSecondary),
        ];
      case DownloadStatus.paused:
        return [
          button(tr('继续'), onResume),
          button(
              tr('删除'),
              () => _confirmRemove(
                    context,
                    title: tr('删除任务和文件'),
                    message: tr('将删除任务、已下载的文件与临时文件，此操作不可恢复。'),
                    actionLabel: tr('确定删除'),
                    deleteFile: true,
                  ),
              color: context.appColors.textSecondary),
        ];
      case DownloadStatus.failed:
        return [
          button(tr('重试'), onResume),
          button(
              tr('删除'),
              () => _confirmRemove(
                    context,
                    title: tr('删除任务和文件'),
                    message: tr('将删除任务、已下载的文件与临时文件，此操作不可恢复。'),
                    actionLabel: tr('确定删除'),
                    deleteFile: true,
                  ),
              color: context.appColors.textSecondary),
        ];
      case DownloadStatus.completed:
        return [
          button(tr('打开'), () => _openFile(context)),
          button(
              tr('删除记录'),
              () => _confirmRemove(
                    context,
                    title: tr('删除记录'),
                    message: tr('仅删除下载记录，已下载的文件会保留。'),
                    actionLabel: tr('确定删除'),
                    deleteFile: false,
                  ),
              color: context.appColors.textSecondary),
        ];
    }
  }

  Future<void> _confirmRemove(
    BuildContext context, {
    required String title,
    required String message,
    required String actionLabel,
    required bool deleteFile,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr('取消')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      onRemove(deleteFile: deleteFile);
    }
  }

  Future<void> _showDetail(BuildContext context) async {
    final action = await showModalBottomSheet<DownloadDetailAction>(
      context: context,
      backgroundColor: context.appColors.surface,
      builder: (_) => DownloadTaskDetailSheet(task: task),
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case DownloadDetailAction.deleteRecord:
        await _confirmRemove(
          context,
          title: tr('删除记录'),
          message: tr('仅删除下载记录，已下载的文件会保留。'),
          actionLabel: tr('确定删除'),
          deleteFile: false,
        );
        break;
      case DownloadDetailAction.deleteTaskAndFile:
        await _confirmRemove(
          context,
          title: tr('删除任务和文件'),
          message: tr('将删除任务、已下载的文件与临时文件，此操作不可恢复。'),
          actionLabel: tr('确定删除'),
          deleteFile: true,
        );
        break;
    }
  }

  Future<void> _openFile(BuildContext context) async {
    if (!File(task.savePath).existsSync()) {
      _toast(context, tr('文件不存在，可能已被移动或删除'));
      return;
    }
    try {
      final result = await OpenFilex.open(task.savePath);
      if (!context.mounted) return;
      if (result.type != ResultType.done) {
        _toast(context, tr('无法打开文件'));
      }
    } catch (e) {
      if (!context.mounted) return;
      _toast(context, tr('无法打开文件'));
    }
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
