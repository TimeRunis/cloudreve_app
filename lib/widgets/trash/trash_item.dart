import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/file_item.dart';
import '../file/file_icon.dart';

/// 回收站条目记录的原位置 URI（`sys:restore_uri`）。
String trashRestoreUri(FileItem item) =>
    item.metadata['sys:restore_uri'] as String? ?? '';

/// 回收站条目的显示名称：优先取原路径的文件名。
String trashDisplayName(FileItem item) {
  final uri = trashRestoreUri(item);
  if (uri.isNotEmpty) {
    try {
      // pathSegments 已完成百分号解码，不能再 decodeComponent 一次，
      // 否则文件名里含 `%` 时会抛 Illegal percent encoding。
      final segments = Uri.parse(uri).pathSegments;
      if (segments.isNotEmpty && segments.last.isNotEmpty) {
        return segments.last;
      }
    } catch (_) {
      // restore uri 含非法转义时忽略，回退到 item.name。
    }
  }
  return item.name;
}

/// 回收站条目原来的位置（去掉 `cloudreve://my` 前缀）。
String trashOriginalPath(FileItem item) {
  final uri = trashRestoreUri(item);
  if (uri.isEmpty) return item.path;
  const prefix = 'cloudreve://my';
  return uri.startsWith(prefix) ? uri.substring(prefix.length) : uri;
}

/// 回收站列表项：图标 + 名称 + 大小/原位置 + 恢复/彻底删除。
class TrashItem extends StatelessWidget {
  final FileItem item;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const TrashItem({
    super.key,
    required this.item,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ListTile(
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
      subtitle: Text(
        '${formatSize(item.size)} · 原位置：${trashOriginalPath(item)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: colors.textSecondary),
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
