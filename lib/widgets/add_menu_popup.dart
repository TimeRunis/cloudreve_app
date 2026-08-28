import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'popup_item.dart';

/// 新建/上传菜单动作。
enum AddMenuAction {
  uploadFile,
  uploadClipboard,
  offlineDownload,
  createFolder,
  createFile,
  createMarkdown,
  createText,
}

/// 「+」号弹出的新建/上传菜单（纯组件：只通过 [onAction] 传出所选动作）。
class AddMenuPopup extends StatelessWidget {
  final ValueChanged<AddMenuAction> onAction;

  const AddMenuPopup({super.key, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 8,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.5,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PopupItem(
                icon: Icons.upload_file_outlined,
                label: '上传文件',
                onTap: () => onAction(AddMenuAction.uploadFile)),
          ],
        ),
      ),
    );
  }
}
