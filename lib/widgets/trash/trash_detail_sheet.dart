import 'package:flutter/material.dart';

import '../../core/format/date_time.dart';
import '../../core/theme/app_colors.dart';
import '../../models/file_item.dart';
import '../file/file_icon.dart';
import 'trash_item.dart';
import '../../core/i18n/app_localizations.dart';

/// 回收站条目详情（纯展示组件）。
///
/// 显示名称、类型、大小、时间与**完整可读的原位置**，路径可复制。
class TrashDetailSheet extends StatelessWidget {
  final FileItem item;
  final VoidCallback onCopyPath;

  const TrashDetailSheet({
    super.key,
    required this.item,
    required this.onCopyPath,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final time = formatDateTime(trashTimestamp(item));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  fileIconForName(trashDisplayName(item)),
                  size: 32,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    trashDisplayName(item),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _row(context, tr('类型'), item.isFolder ? tr('文件夹') : tr('文件')),
            if (!item.isFolder) _row(context, tr('大小'), formatSize(item.size)),
            if (time.isNotEmpty) _row(context, tr('时间'), time),
            _row(context, tr('原位置'), trashOriginalPath(item)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onCopyPath,
                icon: const Icon(Icons.copy, size: 18),
                label: Text(tr('复制原位置')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              key,
              style: TextStyle(color: context.appColors.textMuted),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
