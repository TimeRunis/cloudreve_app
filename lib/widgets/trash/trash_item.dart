import 'package:flutter/material.dart';

import '../../core/format/cloudreve_path.dart';
import '../../core/format/date_time.dart';
import '../../core/theme/app_colors.dart';
import '../../models/file_item.dart';
import '../file/file_icon.dart';

/// 回收站条目记录的原位置 URI（`sys:restore_uri`）。
String trashRestoreUri(FileItem item) =>
    item.metadata['sys:restore_uri'] as String? ?? '';

/// 回收站条目的显示名称：优先取原路径的文件名（服务端的 name 是 UUID）。
String trashDisplayName(FileItem item) {
  final name = readableUriName(trashRestoreUri(item));
  return name.isNotEmpty ? name : item.name;
}

/// 回收站条目原来的位置（已解码的可读路径，如 `/我的文件/报告.pdf`）。
String trashOriginalPath(FileItem item) {
  final uri = trashRestoreUri(item);
  final path = readableCloudrevePath(uri.isNotEmpty ? uri : item.path);
  return path.isEmpty ? '/' : path;
}

/// 回收站条目的时间：优先 `updated_at`（移入回收站时会刷新）。
DateTime? trashTimestamp(FileItem item) => item.updatedAt ?? item.createdAt;

/// 回收站列表项：图标 + 名称 + 大小/时间/原位置。
///
/// 点击条目查看详情（完整原位置可复制），右侧是恢复 / 彻底删除。
class TrashItem extends StatelessWidget {
  final FileItem item;
  final VoidCallback onTap;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const TrashItem({
    super.key,
    required this.item,
    required this.onTap,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final size = item.isFolder ? '' : formatSize(item.size);
    final time = formatDateTime(trashTimestamp(item));
    final meta = [size, time].where((s) => s.isNotEmpty).join(' · ');

    return ListTile(
      isThreeLine: true,
      onTap: onTap,
      leading: Icon(
        fileIconForName(trashDisplayName(item)),
        size: 28,
        color: colors.textSecondary,
      ),
      title: Text(
        trashDisplayName(item),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 14, color: colors.textPrimary),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (meta.isNotEmpty)
            Text(
              meta,
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          Text(
            '原位置：${trashOriginalPath(item)}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: colors.textMuted),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '恢复',
            icon: Icon(Icons.restore, size: 20, color: colors.textSecondary),
            onPressed: onRestore,
          ),
          IconButton(
            tooltip: '彻底删除',
            icon: Icon(Icons.delete_outline,
                size: 20, color: colors.textSecondary),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
