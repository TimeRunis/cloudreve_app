import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/file_item.dart';
import '../file/file_icon.dart';

/// 文件夹卡片（横向：图标 + 名字，长按进入选择）。
class FolderCard extends StatelessWidget {
  final FileItem folder;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onOpen;

  const FolderCard({
    super.key,
    required this.folder,
    required this.isSelected,
    required this.onSelect,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appColors.surfaceMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        onLongPress: onSelect,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                isSelected
                    ? const SelectionCheck(size: 18)
                    : Icon(Icons.folder,
                        size: 18, color: context.appColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      folder.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14, color: context.appColors.textPrimary),
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
