import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 工具栏上的单个图标按钮：带 tooltip 与右侧分隔线。
class ToolbarAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  /// 最后一个按钮不画右侧分隔线。
  final bool last;

  const ToolbarAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: last
                ? null
                : Border(right: BorderSide(color: colors.toolbarBorder)),
          ),
          child: Icon(icon, size: 18, color: colors.textSecondary),
        ),
      ),
    );
  }
}
