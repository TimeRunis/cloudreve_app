import 'package:flutter/material.dart';

import 'app_popup.dart';
import 'popup_item.dart';
import '../../core/i18n/app_localizations.dart';

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
    return AppPopup(
      child: SizedBox(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PopupItem(
                icon: Icons.upload_file_outlined,
                label: tr('上传文件'),
                onTap: () => onAction(AddMenuAction.uploadFile)),
          ],
        ),
      ),
    );
  }
}
