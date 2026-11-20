import 'package:flutter/material.dart';
import '../../core/i18n/app_localizations.dart';

/// 通用确认弹窗：返回 `true` 表示用户点了确认。
///
/// [danger] 为 true 时确认按钮用错误色（删除类操作）。
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String actionLabel,
  bool danger = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(tr('取消')),
        ),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                )
              : null,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(actionLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
