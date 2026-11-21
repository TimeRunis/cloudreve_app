import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_colors.dart';

/// 更新说明的 Markdown 渲染。
///
/// GitHub Release 的 body 本身就是 Markdown，直接展示会比纯文本更易读；
/// 链接点击后用系统浏览器打开，失败时退回复制链接。
class UpdateNotesView extends StatelessWidget {
  final String markdown;

  const UpdateNotesView({super.key, required this.markdown});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final style = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: TextStyle(fontSize: 13, height: 1.6, color: colors.textSecondary),
      h1: TextStyle(
        fontSize: 17,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      h2: TextStyle(
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      h3: TextStyle(
        fontSize: 14.5,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      h4: TextStyle(
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      h5: TextStyle(
        fontSize: 13.5,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      h6: TextStyle(
        fontSize: 13,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      strong: TextStyle(
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      em: TextStyle(fontStyle: FontStyle.italic, color: colors.textSecondary),
      code: TextStyle(
        fontSize: 12,
        height: 1.4,
        fontFamily: 'monospace',
        color: colors.textPrimary,
        backgroundColor: colors.surface,
      ),
      a: TextStyle(
        color: scheme.primary,
        decoration: TextDecoration.underline,
      ),
      listBullet: TextStyle(
        fontSize: 13,
        height: 1.6,
        color: colors.textSecondary,
      ),
      blockquote: TextStyle(
        fontSize: 13,
        height: 1.6,
        color: colors.textSecondary,
      ),
      blockquoteDecoration: BoxDecoration(
        color: colors.surfaceMuted,
        border: Border(left: BorderSide(color: scheme.primary, width: 3)),
        borderRadius: BorderRadius.circular(4),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      codeblockDecoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(6),
      ),
      codeblockPadding: const EdgeInsets.all(8),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      blockSpacing: 8,
      listIndent: 18,
      listBulletPadding: const EdgeInsets.only(right: 6),
    );

    return MarkdownBody(
      data: markdown,
      styleSheet: style,
      // 更新说明里偶尔会带远程图片，不希望在弹窗里加载。
      sizedImageBuilder: (_) => const SizedBox.shrink(),
      onTapLink: (_, href, __) {
        unawaited(_openLink(context, href));
      },
    );
  }

  Future<void> _openLink(BuildContext context, String? href) async {
    final target = href?.trim() ?? '';
    if (target.isEmpty) return;
    final uri = Uri.tryParse(target);
    if (uri == null) return;
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (opened || !context.mounted) return;
    await Clipboard.setData(ClipboardData(text: target));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr('链接已复制'))),
    );
  }
}
