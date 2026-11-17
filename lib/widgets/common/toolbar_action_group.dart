import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'toolbar_action.dart';

/// 工具栏按钮组里的一项。
class ToolbarActionItem {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  /// 可选，用于把悬浮窗锚定到该按钮。
  final Key? key;

  const ToolbarActionItem({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.key,
  });
}

/// 边框包裹的工具栏按钮组，内部自动画竖向分隔线。
class ToolbarActionGroup extends StatelessWidget {
  final List<ToolbarActionItem> actions;

  const ToolbarActionGroup({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: context.appColors.toolbarBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 40,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < actions.length; i++)
              ToolbarAction(
                key: actions[i].key,
                icon: actions[i].icon,
                tooltip: actions[i].tooltip,
                onTap: actions[i].onTap,
                last: i == actions.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}
