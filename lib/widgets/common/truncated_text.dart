import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/i18n/app_localizations.dart';

/// 单行文本：超出可用宽度时用省略号截断，而不是缩放字号。
///
/// 指定 [detailTitle] 后，文本一旦被截断就在末尾附加一个详情图标，
/// 点击弹窗展示完整内容（支持一键复制）。
class TruncatedText extends StatelessWidget {
  final String text;
  final TextStyle style;

  /// 详情弹窗标题；为 null 时不显示详情图标。
  final String? detailTitle;

  const TruncatedText({
    super.key,
    required this.text,
    required this.style,
    this.detailTitle,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    return LayoutBuilder(
      builder: (context, constraints) {
        final showDetail = detailTitle != null &&
            constraints.hasBoundedWidth &&
            _isOverflow(context, constraints.maxWidth, effectiveStyle);
        if (!showDetail) return _buildText(effectiveStyle);
        return Row(
          children: [
            Flexible(child: _buildText(effectiveStyle)),
            _DetailIcon(title: detailTitle!, message: text),
          ],
        );
      },
    );
  }

  Widget _buildText(TextStyle effectiveStyle) => Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: effectiveStyle,
      );

  /// 按实际排版参数测量文本是否会超出单行宽度。
  bool _isOverflow(BuildContext context, double maxWidth, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);
    final overflow = painter.didExceedMaxLines;
    painter.dispose();
    return overflow;
  }
}

/// 截断文案末尾的详情图标，点击弹窗展示完整内容。
class _DetailIcon extends StatelessWidget {
  final String title;
  final String message;

  const _DetailIcon({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tr('查看详情'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.only(left: 4, right: 2, top: 2, bottom: 2),
          child: Icon(
            Icons.info_outline,
            size: 14,
            color: context.appColors.textSecondary,
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: SelectableText(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: dialogContext.appColors.textPrimary,
              ),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.primary,
            ),
            icon: const Icon(Icons.copy_outlined, size: 18),
            label: Text(tr('复制')),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: message));
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr('错误信息已复制'))),
              );
            },
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr('关闭')),
          ),
        ],
      ),
    );
  }
}
