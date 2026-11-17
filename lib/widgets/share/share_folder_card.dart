import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/file_item.dart';
import '../file/file_icon.dart';

/// 分享页里的文件夹卡片（网格布局，选中时显示对勾）。
class ShareFolderCard extends StatelessWidget {
  final FileItem folder;
  final bool isSelected;
  final VoidCallback onOpen;
  final VoidCallback onLongPress;

  const ShareFolderCard({
    super.key,
    required this.folder,
    required this.isSelected,
    required this.onOpen,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.surfaceMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                isSelected
                    ? const SelectionCheck(size: 18)
                    : Icon(Icons.folder, size: 18, color: colors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      folder.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: colors.textPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
