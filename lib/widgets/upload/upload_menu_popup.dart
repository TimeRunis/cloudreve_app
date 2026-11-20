import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../popup/app_popup.dart';
import '../popup/popup_item.dart';

/// 上传队列「更多」菜单动作。
enum UploadMenuAction { overwrite, hideCompleted, retryAll, clearCompleted }

/// 上传队列「更多」菜单（纯组件：只通过 [onAction] 传出所选动作）。
class UploadMenuPopup extends StatelessWidget {
  /// 是否覆盖已有文件（菜单里显示对勾）。
  final bool overwrite;

  /// 是否隐藏已完成任务（菜单里显示对勾）。
  final bool hideCompleted;

  final ValueChanged<UploadMenuAction> onAction;

  const UploadMenuPopup({
    super.key,
    required this.overwrite,
    required this.hideCompleted,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return AppPopup(
      child: SizedBox(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PopupItem(
              icon: Icons.copy_all_outlined,
              label: '覆盖已有文件',
              selected: overwrite,
              onTap: () => onAction(UploadMenuAction.overwrite),
            ),
            PopupItem(
              icon: Icons.visibility_off_outlined,
              label: '隐藏已完成任务',
              selected: hideCompleted,
              onTap: () => onAction(UploadMenuAction.hideCompleted),
            ),
            Divider(height: 1, color: context.appColors.border),
            PopupItem(
              icon: Icons.refresh,
              label: '重试所有失败任务',
              onTap: () => onAction(UploadMenuAction.retryAll),
            ),
            PopupItem(
              icon: Icons.delete_sweep_outlined,
              label: '清除已完成任务',
              onTap: () => onAction(UploadMenuAction.clearCompleted),
            ),
          ],
        ),
      ),
    );
  }
}

/// 以 [anchorKey] 为锚点弹出上传队列菜单。
Future<void> showUploadMenu(
  BuildContext context, {
  required GlobalKey anchorKey,
  required bool overwrite,
  required bool hideCompleted,
  required ValueChanged<UploadMenuAction> onAction,
}) async {
  final action = await showAppPopup<UploadMenuAction>(
    context: context,
    anchorKey: anchorKey,
    builder: (dialogContext) => UploadMenuPopup(
      overwrite: overwrite,
      hideCompleted: hideCompleted,
      onAction: (value) => Navigator.of(dialogContext).pop(value),
    ),
  );
  if (action == null) return;
  onAction(action);
}
