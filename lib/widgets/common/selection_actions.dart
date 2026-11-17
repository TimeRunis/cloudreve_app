import 'package:flutter/material.dart';

import 'app_bar_icon_button.dart';

/// 多选模式下 AppBar 右侧的统一操作区：取消选择 + 更多操作（带数量角标）。
///
/// 主页与分享页共用，保证进入多选后两处的头部完全一致。
class SelectionActions extends StatelessWidget {
  /// 已选数量，同时作为两个按钮的角标数字。
  final int count;

  final VoidCallback onClear;

  /// 点击「更多操作」；弹窗通常以 [moreButtonKey] 为锚点。
  final VoidCallback onMore;

  /// 「更多操作」按钮的 key（即操作菜单的锚点）。
  final Key? moreButtonKey;

  const SelectionActions({
    super.key,
    required this.count,
    required this.onClear,
    required this.onMore,
    this.moreButtonKey,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBarIconButton(
          icon: Icons.close,
          badgeCount: count,
          badgeOffset: const Offset(4, 4),
          tooltip: '取消选择',
          onPressed: onClear,
        ),
        AppBarIconButton(
          key: moreButtonKey,
          icon: Icons.more_horiz,
          badgeCount: count,
          badgeOffset: const Offset(4, 4),
          tooltip: '更多操作',
          onPressed: onMore,
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
