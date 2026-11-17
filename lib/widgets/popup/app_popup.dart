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

/// 悬浮窗相对锚点的弹出方向。
enum AppPopupPlacement { below, above, left, right }

/// 以 [anchorKey] 对应的控件为锚点弹出悬浮窗，点击空白处关闭。
///
/// - [placement] 指定相对锚点的方向（上/下/左/右），默认在下方；
/// - 首选方向放不下时自动换到对侧或其它方向；
/// - 无论落在哪个方向，最终都会被夹回屏幕内，不会溢出；
/// - [alignEnd] 为 true 时，上下方向下右对齐锚点（菜单按钮在右侧更自然）；
/// - 返回点击项通过 `Navigator.pop(value)` 传出的值。
Future<T?> showAppPopup<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  GlobalKey? anchorKey,
  AppPopupPlacement placement = AppPopupPlacement.below,
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
                  placement: placement,
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

/// 按 [AppPopupPlacement] 把悬浮窗摆到锚点旁边，并强制夹在屏幕内。
class _AnchorPopupLayout extends SingleChildLayoutDelegate {
  _AnchorPopupLayout({
    required this.anchorRect,
    required this.gap,
    required this.alignEnd,
    required this.placement,
  });

  final Rect anchorRect;
  final double gap;
  final bool alignEnd;
  final AppPopupPlacement placement;

  static const double _margin = 8;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxWidth =
        (constraints.maxWidth - _margin * 2).clamp(0.0, double.infinity);
    final maxHeight =
        (constraints.maxHeight - _margin * 2).clamp(0.0, double.infinity);
    return BoxConstraints.loose(Size(maxWidth, maxHeight));
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final fitsBelow =
        anchorRect.bottom + gap + childSize.height <= size.height - _margin;
    final fitsAbove = anchorRect.top - gap - childSize.height >= _margin;
    final fitsRight =
        anchorRect.right + gap + childSize.width <= size.width - _margin;
    final fitsLeft = anchorRect.left - gap - childSize.width >= _margin;

    bool fits(AppPopupPlacement p) {
      switch (p) {
        case AppPopupPlacement.below:
          return fitsBelow;
        case AppPopupPlacement.above:
          return fitsAbove;
        case AppPopupPlacement.right:
          return fitsRight;
        case AppPopupPlacement.left:
          return fitsLeft;
      }
    }

    final AppPopupPlacement opposite;
    switch (placement) {
      case AppPopupPlacement.below:
        opposite = AppPopupPlacement.above;
        break;
      case AppPopupPlacement.above:
        opposite = AppPopupPlacement.below;
        break;
      case AppPopupPlacement.right:
        opposite = AppPopupPlacement.left;
        break;
      case AppPopupPlacement.left:
        opposite = AppPopupPlacement.right;
        break;
    }

    var chosen = placement;
    if (!fits(placement)) {
      if (fits(opposite)) {
        chosen = opposite;
      } else {
        for (final candidate in AppPopupPlacement.values) {
          if (candidate == placement || candidate == opposite) continue;
          if (fits(candidate)) {
            chosen = candidate;
            break;
          }
        }
      }
    }

    double left;
    double top;
    switch (chosen) {
      case AppPopupPlacement.below:
        left = alignEnd ? anchorRect.right - childSize.width : anchorRect.left;
        top = anchorRect.bottom + gap;
        break;
      case AppPopupPlacement.above:
        left = alignEnd ? anchorRect.right - childSize.width : anchorRect.left;
        top = anchorRect.top - gap - childSize.height;
        break;
      case AppPopupPlacement.right:
        left = anchorRect.right + gap;
        top = anchorRect.top;
        break;
      case AppPopupPlacement.left:
        left = anchorRect.left - gap - childSize.width;
        top = anchorRect.top;
        break;
    }

    final maxLeft = size.width - childSize.width - _margin;
    final maxTop = size.height - childSize.height - _margin;
    final clampedLeft =
        left.clamp(_margin, maxLeft < _margin ? _margin : maxLeft);
    final clampedTop = top.clamp(_margin, maxTop < _margin ? _margin : maxTop);
    return Offset(clampedLeft.toDouble(), clampedTop.toDouble());
  }

  @override
  bool shouldRelayout(_AnchorPopupLayout oldDelegate) =>
      anchorRect != oldDelegate.anchorRect ||
      gap != oldDelegate.gap ||
      alignEnd != oldDelegate.alignEnd ||
      placement != oldDelegate.placement;
}
