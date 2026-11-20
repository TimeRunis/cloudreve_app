import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../models/download_task.dart';
import '../file/file_icon.dart';
import 'download_style.dart';
import '../../core/i18n/app_localizations.dart';

/// 详情面板里可触发的删除动作。
enum DownloadDetailAction { deleteRecord, deleteTaskAndFile }

/// 下载任务详情：状态、失败原因、大小、线程、创建时间、保存路径与操作。
///
/// 纯展示组件：动作通过 `Navigator.pop(DownloadDetailAction)` 交回调用方。
class DownloadTaskDetailSheet extends StatelessWidget {
  final DownloadTask task;

  const DownloadTaskDetailSheet({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final color = downloadStatusColor(context, task.status);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.appColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _row(
            context,
            tr('状态'),
            task.status == DownloadStatus.failed
                ? '${tr(task.statusLabel)}'
                    '${task.error == null ? '' : '（${task.error}）'}'
                : tr(task.statusLabel),
            valueColor: color,
            dense: true,
          ),
          _row(
            context,
            tr('大小'),
            '${formatSize(task.downloadedBytes)} / ${formatSize(task.totalSize)}'
            ' · ${(task.progress * 100).toStringAsFixed(1)}%',
          ),
          _row(context, tr('线程'), '${task.threadCount}'),
          _row(
            context,
            tr('创建时间'),
            '${task.createdAt.year}-${task.createdAt.month.toString().padLeft(2, '0')}-${task.createdAt.day.toString().padLeft(2, '0')} '
            '${task.createdAt.hour.toString().padLeft(2, '0')}:${task.createdAt.minute.toString().padLeft(2, '0')}',
          ),
          _row(context, tr('保存路径'), task.savePath, dense: true),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary),
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: Text(tr('复制路径')),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: task.savePath));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(tr('路径已复制'))));
                  }
                },
              ),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(
                    foregroundColor: context.appColors.textSecondary),
                onPressed: () => Navigator.of(context)
                    .pop(DownloadDetailAction.deleteRecord),
                child: Text(tr('删除记录')),
              ),
              TextButton(
                style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error),
                onPressed: () => Navigator.of(context)
                    .pop(DownloadDetailAction.deleteTaskAndFile),
                child: Text(tr('删除任务和文件')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
    bool dense = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13, color: context.appColors.textMuted)),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: dense ? 3 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: valueColor ?? context.appColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
