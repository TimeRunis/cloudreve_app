import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/directory_provider.dart';
import '../navigation/breadcrumb.dart';
import 'home_action_group.dart';

/// 主页顶部工具栏：面包屑 + 视图/排序/更多按钮组。
class HomeToolbar extends StatelessWidget implements PreferredSizeWidget {
  final String path;
  final FileCategory? category;
  final ValueChanged<String> onNavigate;
  final VoidCallback onToggleView;
  final VoidCallback onSort;
  final VoidCallback onMore;
  final VoidCallback onOpenBreadcrumb;

  const HomeToolbar({
    super.key,
    required this.path,
    this.category,
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
              path: path,
              category: category,
              onNavigate: onNavigate,
              onOpenCurrentPopup: onOpenBreadcrumb,
            ),
          ),
          const SizedBox(width: 12),
          HomeActionGroup(
            onToggleView: onToggleView,
            onSort: onSort,
            onMore: onMore,
          ),
        ],
      ),
    );
  }
}
