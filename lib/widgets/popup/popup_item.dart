import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 弹出菜单通用条目。
class PopupItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// 是否为当前选中项（右侧显示对勾）。
  final bool selected;

  const PopupItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
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
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14, color: context.appColors.textPrimary),
              ),
            ),
            if (selected)
              Icon(
                Icons.check,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}
