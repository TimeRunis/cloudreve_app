import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/i18n/app_localizations.dart';

/// 删除方式：是否跳过回收站、是否保留物理文件。
class DeleteOptions {
  final bool skipSoftDelete;
  final bool unlink;

  const DeleteOptions({
    required this.skipSoftDelete,
    required this.unlink,
  });
}

/// 删除确认对话框：选择「移入回收站 / 彻底删除」以及是否保留物理文件。
///
/// 返回 null 表示用户取消。
Future<DeleteOptions?> showDeleteConfirmDialog(
  BuildContext context, {
  required int count,
}) {
  var skipSoftDelete = false;
  var unlink = false;

  return showDialog<DeleteOptions>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(tr('删除 {count} 项', args: {'count': count})),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('选择删除方式：'),
                style: TextStyle(
                  fontSize: 13,
                  color: context.appColors.textSecondary,
                ),
              ),
              RadioListTile<bool>(
                value: false,
                groupValue: skipSoftDelete,
                title: Text(tr('移入回收站')),
                subtitle: Text(tr('可恢复（取决于站点回收站设置）')),
                onChanged: (v) =>
                    setDialogState(() => skipSoftDelete = v ?? false),
              ),
              RadioListTile<bool>(
                value: true,
                groupValue: skipSoftDelete,
                title: Text(tr('彻底删除')),
                subtitle: Text(tr('跳过回收站，不可恢复')),
                onChanged: (v) =>
                    setDialogState(() => skipSoftDelete = v ?? true),
              ),
              const Divider(),
              CheckboxListTile(
                value: unlink,
                onChanged: (v) => setDialogState(() => unlink = v ?? false),
                title: Text(tr('保留物理文件')),
                subtitle: Text(tr('解除引用并保留底层文件，需用户组高级删除权限')),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr('取消')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(
              DeleteOptions(
                skipSoftDelete: skipSoftDelete,
                unlink: unlink,
              ),
            ),
            child: Text(tr('确认删除')),
          ),
        ],
      ),
    ),
  );
}
