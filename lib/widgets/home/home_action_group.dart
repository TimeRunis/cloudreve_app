import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../common/toolbar_action.dart';

/// 分段按钮组：视图 / 排序 / 更多，边框包裹 + 内部竖向分隔线。
class HomeActionGroup extends StatelessWidget {
  final VoidCallback onToggleView;
  final VoidCallback onSort;
  final VoidCallback onMore;

  const HomeActionGroup({
    super.key,
    required this.onToggleView,
    required this.onSort,
    required this.onMore,
  });

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
            ToolbarAction(
              icon: Icons.grid_view_outlined,
              tooltip: '切换视图',
              onTap: onToggleView,
            ),
            ToolbarAction(
              icon: Icons.swap_vert,
              tooltip: '排序',
              onTap: onSort,
            ),
            ToolbarAction(
              icon: Icons.more_horiz,
              tooltip: '更多',
              onTap: onMore,
              last: true,
            ),
          ],
        ),
      ),
    );
  }
}
