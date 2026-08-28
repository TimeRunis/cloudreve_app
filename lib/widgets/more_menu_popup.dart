import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'popup_item.dart';

/// 更多操作菜单动作。
enum MoreMenuAction { refresh, pin, selectAll, deselect, invert }

/// 「⋯」号弹出的更多操作菜单（纯组件：通过 [onAction] 传出动作）。
class MoreMenuPopup extends StatelessWidget {
  final ValueChanged<MoreMenuAction> onAction;

  const MoreMenuPopup({super.key, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 8,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.45,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PopupItem(
                icon: Icons.refresh,
                label: '刷新',
                onTap: () => onAction(MoreMenuAction.refresh)),
            Divider(height: 1, color: context.appColors.border),
            PopupItem(
                icon: Icons.select_all,
                label: '全选',
                onTap: () => onAction(MoreMenuAction.selectAll)),
            PopupItem(
                icon: Icons.deselect,
                label: '取消选择',
                onTap: () => onAction(MoreMenuAction.deselect)),
            PopupItem(
                icon: Icons.flip_to_back,
                label: '反选',
                onTap: () => onAction(MoreMenuAction.invert)),
          ],
        ),
      ),
    );
  }
}
