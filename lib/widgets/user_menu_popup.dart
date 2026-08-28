import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/user.dart';
import 'popup_item.dart';

/// 用户菜单动作。
enum UserMenuAction { managePanel, settings, profile, logout }

/// 用户头像弹出的悬浮菜单（纯组件：只通过 [onAction] 传出所选动作）。
class UserMenuPopup extends StatelessWidget {
  final User? user;
  final ValueChanged<UserMenuAction> onAction;

  const UserMenuPopup({super.key, required this.user, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final name = user?.nickname ?? '';
    final email = user?.email ?? '';
    final tag = user?.group?.name ?? '';

    return Material(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 8,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                      ),
                      if (tag.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.appColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(tag,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: context.appColors.textSecondary)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13, color: context.appColors.textMuted)),
                ],
              ),
            ),
            Divider(height: 1, color: context.appColors.border),
            PopupItem(
                icon: Icons.logout,
                label: '退出登录',
                onTap: () => onAction(UserMenuAction.logout)),
          ],
        ),
      ),
    );
  }
}
