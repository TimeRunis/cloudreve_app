import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 导航栏图标按钮：固定 44x44，与头像等其他 actions 对齐；可带数量角标。
class AppBarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  /// 0 表示不显示角标。
  final int badgeCount;

  /// 角标相对右上角的偏移（选择模式与普通模式位置略有差异）。
  final Offset badgeOffset;

  const AppBarIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badgeCount = 0,
    this.badgeOffset = const Offset(2, 2),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          IconButton(
            tooltip: tooltip,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            icon: Icon(icon, size: 22, color: context.appColors.textPrimary),
            onPressed: onPressed,
          ),
          if (badgeCount > 0)
            Positioned(
              top: badgeOffset.dy,
              right: badgeOffset.dx,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
