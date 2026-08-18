import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// 文件 / 目录操作项。
enum FileOperation {
  open, // 打开(文件) / 进入(文件夹)
  download,
  share,
  rename,
  copy,
  directLink,
  tag,
  organize,
  more,
  details,
  delete,
}

/// 操作菜单类型：单个文件夹 / 单个文件 / 多选。
enum FileOperationKind { folder, file, multiple }

/// 文件操作菜单（纯组件：通过 [onAction] 传出操作）。
/// 面包屑末尾目录与多选三点按钮共用。
class FileOperationsPopup extends StatelessWidget {
  final FileOperationKind kind;
  final ValueChanged<FileOperation> onAction;

  const FileOperationsPopup({
    super.key,
    required this.kind,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 8,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _buildItems(context),
        ),
      ),
    );
  }

  List<Widget> _buildItems(BuildContext context) {
    switch (kind) {
      case FileOperationKind.folder:
        return [
          _item(context, Icons.arrow_right, '进入', FileOperation.open),
          _item(context, Icons.file_download_outlined, '下载',
              FileOperation.download),
          _item(context, Icons.share_outlined, '分享', FileOperation.share),
          _item(context, Icons.edit_outlined, '重命名', FileOperation.rename),
          _item(context, Icons.copy_outlined, '复制', FileOperation.copy),
          _item(context, Icons.link, '获取直链', FileOperation.directLink),
          Divider(height: 1, color: context.appColors.border),
          _item(context, Icons.label_outline, '标签', FileOperation.tag,
              trailing: true),
          _item(context, Icons.folder_open, '整理', FileOperation.organize,
              trailing: true),
          _item(context, Icons.build, '更多操作', FileOperation.more,
              trailing: true),
          Divider(height: 1, color: context.appColors.border),
          _item(context, Icons.info_outline, '详细信息', FileOperation.details),
          _item(context, Icons.delete_outline, '删除', FileOperation.delete),
        ];
      case FileOperationKind.file:
        return [
          _item(context, Icons.open_in_new, '打开', FileOperation.open),
          _item(context, Icons.file_download_outlined, '下载',
              FileOperation.download),
          _item(context, Icons.share_outlined, '分享', FileOperation.share),
          _item(context, Icons.edit_outlined, '重命名', FileOperation.rename),
          _item(context, Icons.copy_outlined, '复制', FileOperation.copy),
          _item(context, Icons.link, '获取直链', FileOperation.directLink),
          _item(context, Icons.info_outline, '详细信息', FileOperation.details),
          _item(context, Icons.delete_outline, '删除', FileOperation.delete),
        ];
      case FileOperationKind.multiple:
        return [
          _item(context, Icons.file_download_outlined, '下载',
              FileOperation.download),
          _item(context, Icons.copy_outlined, '复制', FileOperation.copy),
          _item(context, Icons.delete_outline, '删除', FileOperation.delete),
        ];
    }
  }

  Widget _item(
    BuildContext context,
    IconData icon,
    String label,
    FileOperation action, {
    bool trailing = false,
  }) {
    return InkWell(
      onTap: () => onAction(action),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 16, color: context.appColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14, color: context.appColors.textPrimary),
              ),
            ),
            if (trailing)
              Icon(Icons.chevron_right,
                  size: 14, color: context.appColors.textMuted),
          ],
        ),
      ),
    );
  }
}
