import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/file_item.dart';
import 'file_icon.dart';
import 'file_item_icon.dart';

/// 文件夹卡片（横向：图标 + 名字，长按进入选择）。
///
/// [selectionMode] 为 true 时（已有多选项），单击同样是切换选择，而不是进入目录。
class FolderCard extends StatelessWidget {
  final FileItem folder;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback onSelect;
  final VoidCallback onOpen;

  const FolderCard({
    super.key,
    required this.folder,
    required this.isSelected,
    required this.onSelect,
    required this.onOpen,
    this.selectionMode = false,
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
        onTap: selectionMode ? onSelect : onOpen,
        onLongPress: onSelect,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                isSelected
                    ? const SelectionCheck(size: 18)
                    : FileItemIcon(
                        file: folder,
                        size: 24,
                        color: context.appColors.textSecondary,
                      ),
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
