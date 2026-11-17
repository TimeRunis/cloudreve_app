import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 区块小标题。
///
/// 两种用法：
/// - [SectionTitle.settings]：设置页那种 14px 次级色 + 下方 8px 间距；
/// - [SectionTitle.content]：内容区标题，15px / w500 / 主色。
class SectionTitle extends StatelessWidget {
  final String text;
  final bool emphasized;
  final EdgeInsetsGeometry padding;

  const SectionTitle(
    this.text, {
    super.key,
    this.emphasized = false,
    this.padding = EdgeInsets.zero,
  });

  /// 设置页风格：14px 次级色，下方留 8px。
  const SectionTitle.settings(this.text, {super.key})
      : emphasized = false,
        padding = const EdgeInsets.only(bottom: 8);

  /// 内容区风格：15px / w500 / 主色。
  const SectionTitle.content(this.text, {super.key})
      : emphasized = true,
        padding = EdgeInsets.zero;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: emphasized
            ? TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              )
            : TextStyle(fontSize: 14, color: colors.textSecondary),
      ),
    );
  }
}
