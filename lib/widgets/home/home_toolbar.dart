import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/directory_provider.dart';
import '../common/toolbar_action_group.dart';
import '../navigation/breadcrumb.dart';

/// 主页顶部工具栏：面包屑 + 视图/排序/更多按钮组。
class HomeToolbar extends StatelessWidget implements PreferredSizeWidget {
  /// 当前路径层级（原始段）。
  final List<String> segments;
  final FileCategory? category;

  /// 「排序」按钮的 key，排序菜单以它为锚点。
  final Key? sortButtonKey;

  /// 「视图」按钮的 key，视图面板以它为锚点。
  final Key? viewButtonKey;

  /// 面包屑的 key，目录操作菜单以它为锚点。
  final Key? breadcrumbKey;

  /// 「更多」按钮的 key，更多菜单以它为锚点。
  final Key? moreButtonKey;

  /// 点击面包屑层级：0 = 根，i = 保留前 i 段。
  final ValueChanged<int> onNavigate;
  final VoidCallback onToggleView;
  final VoidCallback onSort;
  final VoidCallback onMore;
  final VoidCallback onOpenBreadcrumb;

  const HomeToolbar({
    super.key,
    required this.segments,
    this.category,
    this.sortButtonKey,
    this.viewButtonKey,
    this.breadcrumbKey,
    this.moreButtonKey,
    required this.onNavigate,
    required this.onToggleView,
    required this.onSort,
    required this.onMore,
    required this.onOpenBreadcrumb,
  });

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: context.appColors.contentBg, width: 2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Breadcrumb(
              key: breadcrumbKey,
              segments: segments,
              category: category,
              onNavigate: onNavigate,
              onOpenCurrentMenu: onOpenBreadcrumb,
            ),
          ),
          const SizedBox(width: 12),
          ToolbarActionGroup(
            actions: [
              ToolbarActionItem(
                key: viewButtonKey,
                icon: Icons.grid_view_outlined,
                tooltip: '切换视图',
                onTap: onToggleView,
              ),
              ToolbarActionItem(
                key: sortButtonKey,
                icon: Icons.swap_vert,
                tooltip: '排序',
                onTap: onSort,
              ),
              ToolbarActionItem(
                key: moreButtonKey,
                icon: Icons.more_horiz,
                tooltip: '更多',
                onTap: onMore,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
