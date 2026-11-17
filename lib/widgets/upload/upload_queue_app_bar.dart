import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 上传队列标题栏：返回、添加文件、更多菜单。
///
/// 只负责展示与发出动作，菜单里的业务处理留在页面。
class UploadQueueAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// 是否覆盖已有文件（菜单里显示对勾）。
  final bool overwrite;

  /// 是否隐藏已完成任务（菜单里显示对勾）。
  final bool hideCompleted;

  final VoidCallback onClose;
  final VoidCallback onPickFiles;

  /// 菜单动作：overwrite / hide_completed / retry_all / clear_completed。
  final ValueChanged<String> onMenuSelected;

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
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AppBar(
      backgroundColor: colors.headerBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        tooltip: '返回',
        icon: Icon(Icons.close, size: 18, color: colors.textSecondary),
        onPressed: onClose,
      ),
      title: Text(
        '上传队列',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: colors.textPrimary,
        ),
      ),
      actions: [
        IconButton(
          tooltip: '添加文件',
          icon: Icon(Icons.add, size: 20, color: colors.textSecondary),
          onPressed: onPickFiles,
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_horiz, color: colors.textSecondary),
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: colors.border),
          ),
          onSelected: onMenuSelected,
          itemBuilder: (context) => [
            _menuItem(context, 'overwrite', '覆盖已有文件', overwrite),
            _menuItem(context, 'hide_completed', '隐藏已完成任务', hideCompleted),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'retry_all',
              child: Text('重试所有失败任务'),
            ),
            const PopupMenuItem(
              value: 'clear_completed',
              child: Text('清除已完成任务'),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(
    BuildContext context,
    String value,
    String label,
    bool checked,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Expanded(child: Text(label)),
          if (checked)
            Icon(
              Icons.check,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
        ],
      ),
    );
  }
}
