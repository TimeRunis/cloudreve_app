import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_colors.dart';

/// 加载失败占位：图标 + 说明文案 + 可选重试按钮。
class ErrorView extends StatelessWidget {
  final String message;

  /// 图标可按场景替换（例如分享失效用 [Icons.link_off_outlined]）。
  final IconData icon;

  /// 为空时不显示重试按钮。
  final VoidCallback? onRetry;

  final String? retryLabel;

  const ErrorView({
    super.key,
    required this.message,
    this.icon = Icons.error_outline,
    this.onRetry,
    this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: colors.textMuted),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: colors.textSecondary),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(retryLabel ?? tr('重试')),
            ),
          ],
        ],
      ),
    );
  }
}
