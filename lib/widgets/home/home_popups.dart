import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../providers/directory_provider.dart';
import '../file/view_panel.dart';
import '../navigation/sidebar_panel.dart';
import '../popup/add_menu_popup.dart';
import '../popup/app_popup.dart';
import '../popup/file_operations_popup.dart';
import '../popup/more_menu_popup.dart';
import '../popup/search_popup.dart';
import '../popup/user_menu_popup.dart';

/// 主页各类悬浮窗的启动器。
///
/// 只负责弹出与定位，业务处理全部通过回调交回页面；定位方式与页面里
/// 原有的 `showGeneralDialog`（透明遮罩 + 固定坐标）保持一致。
const Duration _popupDuration = Duration(milliseconds: 150);

/// 透明遮罩 + 固定坐标面板。
class _Panel extends StatelessWidget {
  final Widget child;
  final double top;
  final double? left;
  final double? right;
  final bool dismissible;

  const _Panel({
    required this.child,
    required this.top,
    this.left,
    this.right,
    this.dismissible = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (dismissible)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const SizedBox.expand(),
            ),
          ),
        Positioned(top: top, left: left, right: right, child: child),
      ],
    );
  }
}

Future<void> _showPanel(
  BuildContext context, {
  required String barrierLabel,
  required double top,
  double? left,
  double? right,
  required Widget Function(BuildContext dialogContext) builder,
  Color barrierColor = Colors.transparent,
  bool dismissible = true,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: barrierColor,
    transitionDuration: _popupDuration,
    pageBuilder: (dialogContext, animation, secondaryAnimation) => _Panel(
      top: top,
      left: left,
      right: right,
      dismissible: dismissible,
      child: builder(dialogContext),
    ),
  );
}

/// 侧边栏（从左滑入，点击空白关闭）。
Future<void> showHomeSidebar(
  BuildContext context, {
  required String title,
  required ValueChanged<String> onNavigate,
  required VoidCallback onPlaceholder,
  required VoidCallback onCycleTheme,
  required ValueChanged<FileCategory> onCategory,
  required VoidCallback onManageSites,
  required VoidCallback onDownloads,
  required VoidCallback onTrash,
  required VoidCallback onMyShares,
  required VoidCallback onSettings,
}) {
  final topPad = MediaQuery.of(context).padding.top;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'sidebar',
    barrierColor: Colors.transparent,
    transitionDuration: _popupDuration,
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final offset = Tween<Offset>(
        begin: const Offset(-0.2, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
      return SlideTransition(position: offset, child: child);
    },
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      void close() => Navigator.of(dialogContext).pop();
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: close,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            top: topPad + 16,
            left: 16,
            child: SidebarPanel(
              title: title,
              onNavigate: (path) {
                close();
                onNavigate(path);
              },
              onPlaceholder: () {
                close();
                onPlaceholder();
              },
              // 主题切换不关闭侧边栏，与原有行为一致。
              onCycleTheme: onCycleTheme,
              onCategory: (category) {
                close();
                onCategory(category);
              },
              onManageSites: () {
                close();
                onManageSites();
              },
              onDownloads: () {
                close();
                onDownloads();
              },
              onTrash: () {
                close();
                onTrash();
              },
              onMyShares: () {
                close();
                onMyShares();
              },
              onSettings: () {
                close();
                onSettings();
              },
            ),
          ),
        ],
      );
    },
  );
}

/// 右上角用户菜单。
Future<void> showHomeUserMenu(
  BuildContext context, {
  required User? user,
  required ValueChanged<UserMenuAction> onAction,
}) {
  final topPad = MediaQuery.of(context).padding.top;
  return _showPanel(
    context,
    barrierLabel: 'user-menu',
    top: topPad + kToolbarHeight + 8,
    right: 16,
    builder: (dialogContext) => UserMenuPopup(
      user: user,
      onAction: (action) {
        Navigator.of(dialogContext).pop();
        onAction(action);
      },
    ),
  );
}

/// 「+」新建/上传菜单。
Future<void> showHomeAddMenu(
  BuildContext context, {
  required ValueChanged<AddMenuAction> onAction,
}) {
  final topPad = MediaQuery.of(context).padding.top;
  return _showPanel(
    context,
    barrierLabel: 'add-menu',
    top: topPad + kToolbarHeight + 8,
    right: 56,
    builder: (dialogContext) => AddMenuPopup(
      onAction: (action) {
        Navigator.of(dialogContext).pop();
        onAction(action);
      },
    ),
  );
}

/// 顶部搜索弹窗（遮罩加深，点击空白关闭）。
Future<void> showHomeSearch(
  BuildContext context, {
  required ValueChanged<String> onSubmitted,
}) {
  final topPad = MediaQuery.of(context).padding.top;
  return _showPanel(
    context,
    barrierLabel: 'search',
    barrierColor: Colors.black45,
    dismissible: false,
    top: topPad + 12,
    left: 12,
    right: 12,
    builder: (dialogContext) => SearchPopup(
      onSubmitted: (query) {
        Navigator.of(dialogContext).pop();
        onSubmitted(query);
      },
    ),
  );
}

/// 视图设置面板（以 [anchorKey] 为锚点弹出，越界会被夹回屏幕内）。
Future<void> showHomeViewPanel(
  BuildContext context, {
  required GlobalKey anchorKey,
  required String viewMode,
  required bool thumbnails,
  required int pageSize,
  required ValueChanged<String> onViewModeChanged,
  required ValueChanged<bool> onThumbnailsChanged,
  required ValueChanged<int> onPageSizeChanged,
}) {
  return showAppPopup<void>(
    context: context,
    anchorKey: anchorKey,
    placement: AppPopupPlacement.below,
    builder: (_) => ViewPanel(
      initialViewMode: viewMode,
      initialThumbnails: thumbnails,
      initialPageSize: pageSize,
      onViewModeChanged: onViewModeChanged,
      onThumbnailsChanged: onThumbnailsChanged,
      onPageSizeChanged: onPageSizeChanged,
    ),
  );
}

/// 面包屑末尾目录的操作菜单。
Future<void> showHomeFolderOperations(
  BuildContext context, {
  required ValueChanged<FileOperation> onAction,
}) {
  final topPad = MediaQuery.of(context).padding.top;
  return _showPanel(
    context,
    barrierLabel: 'breadcrumb',
    top: topPad + kToolbarHeight + 40,
    left: 16,
    builder: (dialogContext) => FileOperationsPopup(
      kind: FileOperationKind.folder,
      onAction: (action) {
        Navigator.of(dialogContext).pop();
        onAction(action);
      },
    ),
  );
}

/// 多选模式下的操作菜单。
Future<void> showHomeSelectionOperations(
  BuildContext context, {
  required FileOperationKind kind,
  required ValueChanged<FileOperation> onAction,
}) {
  final topPad = MediaQuery.of(context).padding.top;
  return _showPanel(
    context,
    barrierLabel: 'selection-menu',
    top: topPad + kToolbarHeight + 8,
    right: 8,
    builder: (dialogContext) => FileOperationsPopup(
      kind: kind,
      onAction: (action) {
        Navigator.of(dialogContext).pop();
        onAction(action);
      },
    ),
  );
}

/// 工具栏「更多」菜单。
Future<void> showHomeMoreMenu(
  BuildContext context, {
  required ValueChanged<MoreMenuAction> onAction,
}) {
  final topPad = MediaQuery.of(context).padding.top;
  return _showPanel(
    context,
    barrierLabel: 'more-menu',
    top: topPad + kToolbarHeight + 40,
    right: 8,
    builder: (dialogContext) => MoreMenuPopup(
      onAction: (action) {
        Navigator.of(dialogContext).pop();
        onAction(action);
      },
    ),
  );
}
