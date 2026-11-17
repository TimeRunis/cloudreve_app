import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 空状态占位：图标 + 标题 + 可选副标题 + 可选操作按钮。
///
/// 上传队列、下载列表、站点列表、根页面共用一套排版。
class EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  /// 传了 [actionLabel] 与 [onAction] 才显示按钮。
  final String? actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;

  final double iconSize;

  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.actionIcon = Icons.add,
    this.onAction,
    this.iconSize = 56,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: colors.textMuted),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(fontSize: 15, color: colors.textSecondary),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: colors.textMuted),
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: Icon(actionIcon),
              label: Text(actionLabel!),
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}
