import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/file_item.dart';
import 'file_icon.dart';
import 'file_thumbnail.dart';

/// 文件卡片（网格视图，纵向：名字行 + 缩略图）。
/// 纯组件：通过 [onSelect] / [onOpen] 把交互传出去。
class FileCard extends StatelessWidget {
  final FileItem file;
  final bool isSelected;
  final bool showThumb;
  final VoidCallback onSelect;
  final VoidCallback onOpen;

  const FileCard({
    super.key,
    required this.file,
    required this.isSelected,
    required this.onSelect,
    required this.onOpen,
    this.showThumb = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: context.appColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: context.appColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Row(
                    children: [
                      if (isSelected)
                        const SelectionCheck(size: 20)
                      else
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: fileIconColor(context, file),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Icon(fileIcon(file),
                              size: 14, color: Colors.white),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              color: context.appColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    color: context.appColors.surfaceMuted,
                    alignment: Alignment.center,
                    child: showThumb
                        ? FileThumbnail(file: file, size: 64, fill: true)
                        : Icon(fileIcon(file),
                            size: 40, color: fileIconColor(context, file)),
                  ),
                ),
              ],
            ),
            // 覆盖整卡（含缩略图区域）的墨水展开层，置于内容之上。
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onSelect,
                  onDoubleTap: onOpen,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
