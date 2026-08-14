import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// 弹出菜单通用条目。
class PopupItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const PopupItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 16, color: context.appColors.textSecondary),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    fontSize: 14, color: context.appColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
