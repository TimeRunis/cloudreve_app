import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'upload_menu_popup.dart';
import '../../core/i18n/app_localizations.dart';

/// 上传队列标题栏：返回、添加文件、更多菜单。
///
/// 只负责展示与发出动作，菜单里的业务处理留在页面；
/// 「更多」菜单与全 App 其它菜单一样走 [showUploadMenu]（AppPopup）。
class UploadQueueAppBar extends StatefulWidget implements PreferredSizeWidget {
  /// 是否覆盖已有文件（菜单里显示对勾）。
  final bool overwrite;

  /// 是否隐藏已完成任务（菜单里显示对勾）。
  final bool hideCompleted;

  final VoidCallback onClose;
  final VoidCallback onPickFiles;

  /// 菜单动作回调。
  final ValueChanged<UploadMenuAction> onMenuSelected;

  const UploadQueueAppBar({
    super.key,
    required this.overwrite,
    required this.hideCompleted,
    required this.onClose,
    required this.onPickFiles,
    required this.onMenuSelected,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<UploadQueueAppBar> createState() => _UploadQueueAppBarState();
}

class _UploadQueueAppBarState extends State<UploadQueueAppBar> {
  /// 「更多」按钮，作为菜单悬浮窗的锚点。
  final GlobalKey _menuKey = GlobalKey();

  Future<void> _openMenu() {
    return showUploadMenu(
      context,
      anchorKey: _menuKey,
      overwrite: widget.overwrite,
      hideCompleted: widget.hideCompleted,
      onAction: widget.onMenuSelected,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AppBar(
      backgroundColor: colors.headerBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        tooltip: tr('返回'),
        icon: Icon(Icons.close, size: 18, color: colors.textSecondary),
        onPressed: widget.onClose,
      ),
      title: Text(
        tr('上传队列'),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: colors.textPrimary,
        ),
      ),
      actions: [
        IconButton(
          tooltip: tr('添加文件'),
          icon: Icon(Icons.add, size: 20, color: colors.textSecondary),
          onPressed: widget.onPickFiles,
        ),
        KeyedSubtree(
          key: _menuKey,
          child: IconButton(
            tooltip: tr('更多操作'),
            icon: Icon(Icons.more_horiz, color: colors.textSecondary),
            onPressed: _openMenu,
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
