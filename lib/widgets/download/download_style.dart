import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/download_task.dart';
import '../file/file_icon.dart';

/// 下载状态对应的强调色（进度条、状态圆点、详情里的状态文字共用）。
Color downloadStatusColor(BuildContext context, DownloadStatus status) {
  switch (status) {
    case DownloadStatus.downloading:
      return Theme.of(context).colorScheme.primary;
    case DownloadStatus.waiting:
      return context.appColors.textSecondary;
    case DownloadStatus.paused:
      return Colors.orange;
    case DownloadStatus.completed:
      return Colors.green;
    case DownloadStatus.failed:
      return Theme.of(context).colorScheme.error;
  }
}

/// 速度文案：`12.3 MB/s`，无速度时显示破折号。
String formatSpeed(int bytesPerSecond) =>
    bytesPerSecond <= 0 ? '—' : '${formatSize(bytesPerSecond)}/s';
