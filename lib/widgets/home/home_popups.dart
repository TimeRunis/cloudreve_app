import 'package:flutter/material.dart';

import '../../models/file_item.dart';
import '../../models/user.dart';
import '../../providers/directory_provider.dart';
import '../file/view_panel.dart';
import '../navigation/sidebar_panel.dart';
import '../popup/add_menu_popup.dart';
import '../popup/app_popup.dart';
import '../popup/more_menu_popup.dart';
import '../popup/search_popup.dart';
import '../popup/user_menu_popup.dart';

/// 主页各类悬浮窗的启动器。
///
/// 统一走 [showAppPopup]：以触发按钮 [anchorKey] 为锚点定位，
/// 越界会被夹回屏幕内；业务处理全部通过回调交回页面。

/// 侧边栏（从左滑入，点击空白关闭）。
Future<void> showHomeSidebar(
  BuildContext context, {
  required GlobalKey anchorKey,
  required ValueChanged<FileItem> onNavigate,
  required VoidCallback onPlaceholder,
  required VoidCallback onCycleTheme,
  required ValueChanged<FileCategory> onCategory,
  required VoidCallback onDownloads,
  required VoidCallback onTrash,
  required VoidCallback onMyShares,
  required bool sharedWithMeActive,
  required VoidCallback onSharedWithMe,
  required VoidCallback onSettings,
}) {
  return showAppPopup<void>(
    context: context,
    anchorKey: anchorKey,
    gap: 8,
    // 侧边栏是特殊面板：贴回屏幕左上角（左侧 16，顶部状态栏下 16）。
    offset: const Offset(8, -48),
    // 「与我共享」展开会改变面板高度；始终从左侧展开，避免自动改为
    // 从右侧弹出导致左边距跳动。
    autoFlip: false,
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final offset = Tween<Offset>(
        begin: const Offset(-0.2, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
      return SlideTransition(position: offset, child: child);
    },
    builder: (dialogContext) {
      void close() => Navigator.of(dialogContext).pop();
      return SidebarPanel(
        sharedWithMeActive: sharedWithMeActive,
        onNavigate: (folder) {
          close();
          onNavigate(folder);
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
        onSharedWithMe: () {
          close();
          onSharedWithMe();
        },
        onSettings: () {
          close();
          onSettings();
        },
      );
    },
  );
}

/// 右上角用户菜单。
Future<void> showHomeUserMenu(
  BuildContext context, {
  required GlobalKey anchorKey,
  required User? user,
  required ValueChanged<UserMenuAction> onAction,
}) {
  return showAppPopup<void>(
    context: context,
    anchorKey: anchorKey,
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
  required GlobalKey anchorKey,
  required ValueChanged<AddMenuAction> onAction,
}) {
  return showAppPopup<void>(
    context: context,
    anchorKey: anchorKey,
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
  required GlobalKey anchorKey,
  required ValueChanged<String> onSubmitted,
  required VoidCallback onShareHistory,
}) {
  return showAppPopup<void>(
    context: context,
    anchorKey: anchorKey,
    barrierColor: Colors.black45,
    builder: (dialogContext) => SearchPopup(
      onSubmitted: (query) {
        Navigator.of(dialogContext).pop();
        onSubmitted(query);
      },
      onShareHistory: () {
        Navigator.of(dialogContext).pop();
        onShareHistory();
      },
    ),
  );
}

/// 视图设置面板。
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

/// 工具栏「更多」菜单。
Future<void> showHomeMoreMenu(
  BuildContext context, {
  required GlobalKey anchorKey,
  required ValueChanged<MoreMenuAction> onAction,
}) {
  return showAppPopup<void>(
    context: context,
    anchorKey: anchorKey,
    builder: (dialogContext) => MoreMenuPopup(
      onAction: (action) {
        Navigator.of(dialogContext).pop();
        onAction(action);
      },
    ),
  );
}
