import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/download_task.dart';
import '../file/file_icon.dart';
import 'download_style.dart';
import '../../core/i18n/app_localizations.dart';

/// 下载页顶部汇总卡：下载中/排队中/总速度/已完成 + 总进度。
///
/// 纯展示组件：数值由页面计算后传入。
class DownloadSummaryCard extends StatelessWidget {
  final int downloading;
  final int queued;
  final int completed;
  final int totalSpeed;

  /// 未完成的任务，用于计算总进度。
  final List<DownloadTask> activeTasks;

  const DownloadSummaryCard({
    super.key,
    required this.downloading,
    required this.queued,
    required this.completed,
    required this.totalSpeed,
    required this.activeTasks,
  });

  @override
  Widget build(BuildContext context) {
    final totalBytes = activeTasks.fold<int>(0, (sum, t) => sum + t.totalSize);
    final doneBytes =
        activeTasks.fold<int>(0, (sum, t) => sum + t.downloadedBytes);
    final overall = totalBytes <= 0
        ? 0.0
        : (doneBytes / totalBytes).clamp(0.0, 1.0).toDouble();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _stat(context, tr('下载中'), '$downloading'),
              _divider(context),
              _stat(context, tr('排队中'), '$queued'),
              _divider(context),
              _stat(context, tr('总速度'), formatSpeed(totalSpeed)),
              _divider(context),
              _stat(context, tr('已完成'), '$completed'),
            ],
          ),
          if (activeTasks.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: overall,
                minHeight: 5,
                color: Theme.of(context).colorScheme.primary,
                backgroundColor: context.appColors.surfaceMuted,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  tr('总进度 {percent}%', args: {
                    'percent': (overall * 100).toStringAsFixed(1),
                  }),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.appColors.textSecondary),
                ),
                const Spacer(),
                Text(
                  '${formatSize(doneBytes)} / ${formatSize(totalBytes)}',
                  style: TextStyle(
                      fontSize: 11, color: context.appColors.textMuted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.appColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: context.appColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) => Container(
        width: 1,
        height: 26,
        color: context.appColors.border,
      );
}
