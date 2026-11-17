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

/// 回收站列表项（卡片）：图标 + 名称 + 大小/时间/原位置，底部恢复 / 彻底删除。
///
/// 点击卡片查看详情（完整原位置可复制）。样式与下载任务卡片保持一致。
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
    final name = trashDisplayName(item);
    final size = item.isFolder ? '' : formatSize(item.size);
    final time = formatDateTime(trashTimestamp(item));
    final meta = [size, time].where((s) => s.isNotEmpty).join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  // 图标与右侧文字块垂直居中对齐。
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _thumb(colors, name),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          if (meta.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              meta,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 2),
                          Text(
                            '原位置：${trashOriginalPath(item)}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _actionButton(
                      Icons.restore,
                      '恢复',
                      onRestore,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    _actionButton(
                      Icons.delete_outline,
                      '彻底删除',
                      onDelete,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 类型图标块：与下载卡片的缩略图同尺寸、同圆角。
  Widget _thumb(AppColors colors, String name) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 44,
        height: 44,
        color: colors.surfaceMuted,
        alignment: Alignment.center,
        child: Icon(
          fileIconForName(name),
          size: 22,
          color: colors.textSecondary,
        ),
      ),
    );
  }

  Widget _actionButton(
    IconData icon,
    String label,
    VoidCallback onTap, {
    required Color color,
  }) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}
