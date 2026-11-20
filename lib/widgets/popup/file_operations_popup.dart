import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'app_popup.dart';

/// 文件 / 目录 / 选择相关的操作项。
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

  /// 选择类操作（多选菜单扩展用）。
  selectAll,
  invert,
}

/// 操作对象类型：单个文件夹 / 单个文件 / 多选。
enum FileOperationKind { folder, file, multiple }

/// 按对象类型给出默认操作集（不含选择类操作）。
const Map<FileOperationKind, List<FileOperation>> _defaultOperations = {
  FileOperationKind.folder: [FileOperation.share, FileOperation.delete],
  FileOperationKind.file: [
    FileOperation.download,
    FileOperation.share,
    FileOperation.delete,
  ],
  FileOperationKind.multiple: [FileOperation.download, FileOperation.delete],
};

/// 取某类对象的默认操作集。
List<FileOperation> fileOperationsFor(FileOperationKind kind) =>
    _defaultOperations[kind]!;

/// 操作项的图标与文案。
class _OperationStyle {
  final IconData icon;
  final String label;

  const _OperationStyle(this.icon, this.label);
}

const Map<FileOperation, _OperationStyle> _styles = {
  FileOperation.open: _OperationStyle(Icons.open_in_new, '打开'),
  FileOperation.download: _OperationStyle(Icons.file_download_outlined, '下载'),
  FileOperation.share: _OperationStyle(Icons.share_outlined, '分享'),
  FileOperation.rename: _OperationStyle(Icons.drive_file_rename_outline, '重命名'),
  FileOperation.copy: _OperationStyle(Icons.copy_outlined, '复制'),
  FileOperation.directLink: _OperationStyle(Icons.link, '获取直链'),
  FileOperation.tag: _OperationStyle(Icons.sell_outlined, '标签'),
  FileOperation.organize: _OperationStyle(Icons.folder_copy_outlined, '整理'),
  FileOperation.more: _OperationStyle(Icons.more_horiz, '更多操作'),
  FileOperation.details: _OperationStyle(Icons.info_outline, '详细信息'),
  FileOperation.delete: _OperationStyle(Icons.delete_outline, '删除'),
  FileOperation.selectAll: _OperationStyle(Icons.select_all, '全选'),
  FileOperation.invert: _OperationStyle(Icons.flip_to_back, '反选'),
};

/// 这些操作前会插入一条分组分隔线。
const Set<FileOperation> _dividerBefore = {
  FileOperation.delete,
  FileOperation.selectAll,
};

/// 文件操作菜单（纯组件：按 [operations] 顺序渲染，通过 [onAction] 传出操作）。
///
/// 主页的目录菜单 / 多选菜单、分享页的多选菜单共用。
class FileOperationsPopup extends StatelessWidget {
  final List<FileOperation> operations;
  final ValueChanged<FileOperation> onAction;

  const FileOperationsPopup({
    super.key,
    required this.operations,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (final operation in operations) {
      if (items.isNotEmpty && _dividerBefore.contains(operation)) {
        items.add(Divider(height: 1, color: context.appColors.border));
      }
      items.add(_item(context, operation));
    }
    return AppPopup(
      child: SizedBox(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: items,
        ),
      ),
    );
  }

  Widget _item(BuildContext context, FileOperation operation) {
    final style = _styles[operation]!;
    return InkWell(
      onTap: () => onAction(operation),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(style.icon, size: 16, color: context.appColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tr(style.label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14, color: context.appColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 以 [anchorKey] 为锚点弹出文件操作菜单。
Future<void> showFileOperations(
  BuildContext context, {
  required GlobalKey anchorKey,
  required List<FileOperation> operations,
  required ValueChanged<FileOperation> onAction,
}) {
  return showAppPopup<void>(
    context: context,
    anchorKey: anchorKey,
    builder: (dialogContext) => FileOperationsPopup(
      operations: operations,
      onAction: (action) {
        Navigator.of(dialogContext).pop();
        onAction(action);
      },
    ),
  );
}
