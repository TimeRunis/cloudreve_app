import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 通用悬浮窗容器。
///
/// 统一圆角、阴影、背景色与裁剪。所有弹出菜单 / 面板都套这一层，
/// 保证不同页面弹出来的窗口是同一套外观（此前每个菜单各写一份 Material）。
class AppPopup extends StatelessWidget {
  final Widget child;

  /// 固定宽度；为 null 时由内容决定。
  final double? width;

  final EdgeInsetsGeometry padding;

  /// 阴影高度，默认与既有菜单一致（8）。
  final double elevation;

  const AppPopup({
    super.key,
    required this.child,
    this.width,
    this.padding = EdgeInsets.zero,
    this.elevation = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: elevation,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// 以 [anchorKey] 对应的控件为锚点弹出悬浮窗，点击空白处关闭。
///
/// - 默认右对齐：弹窗右边缘贴住锚点右边缘（菜单按钮在右侧时更自然）；
/// - 下方空间不足时自动翻到锚点上方；
/// - 左右越界会被夹回屏幕内；
/// - 返回点击项通过 `Navigator.pop(value)` 传出的值。
Future<T?> showAppPopup<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  GlobalKey? anchorKey,
  bool alignEnd = true,
  double gap = 6,
  bool barrierDismissible = true,
}) {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  final anchorBox = anchorKey?.currentContext?.findRenderObject() as RenderBox?;
  Rect? anchorRect;
  if (overlay != null && anchorBox != null && anchorBox.hasSize) {
    anchorRect = Rect.fromPoints(
      anchorBox.localToGlobal(Offset.zero, ancestor: overlay),
      anchorBox.localToGlobal(
        anchorBox.size.bottomRight(Offset.zero),
        ancestor: overlay,
      ),
    );
  }

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'app-popup',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final rect = anchorRect;
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(dialogContext).pop(),
              child: const SizedBox.expand(),
            ),
          ),
          if (rect == null)
            Center(child: builder(dialogContext))
          else
            Positioned.fill(
              child: CustomSingleChildLayout(
                delegate: _AnchorPopupLayout(
                  anchorRect: rect,
                  gap: gap,
                  alignEnd: alignEnd,
                ),
                child: builder(dialogContext),
              ),
            ),
        ],
      );
    },
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// 把悬浮窗摆到锚点下方，并做屏幕边界收敛。
class _AnchorPopupLayout extends SingleChildLayoutDelegate {
  _AnchorPopupLayout({
    required this.anchorRect,
    required this.gap,
    required this.alignEnd,
  });

  final Rect anchorRect;
  final double gap;
  final bool alignEnd;

  static const double _margin = 8;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(Size(
      constraints.maxWidth - _margin * 2,
      constraints.maxHeight - _margin * 2,
    ));
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final maxLeft = size.width - childSize.width - _margin;
    var left = alignEnd ? anchorRect.right - childSize.width : anchorRect.left;
    if (left < _margin) left = _margin;
    if (left > maxLeft) left = maxLeft < _margin ? _margin : maxLeft;

    var top = anchorRect.bottom + gap;
    if (top + childSize.height > size.height - _margin) {
      // 下方放不下就翻到锚点上方。
      top = anchorRect.top - gap - childSize.height;
    }
    if (top < _margin) top = _margin;
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_AnchorPopupLayout oldDelegate) =>
      anchorRect != oldDelegate.anchorRect ||
      gap != oldDelegate.gap ||
      alignEnd != oldDelegate.alignEnd;
}
