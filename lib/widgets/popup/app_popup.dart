import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 悬浮窗宽度：窄屏（< 600）屏幕 75%、宽屏（600–999）40%、
/// 超宽屏（≥ 1000）30%，任何情况下都不超过屏幕宽度。
///
/// 所有悬浮窗（菜单 / 面板 / 侧边栏）统一按这个档位取宽。
double appPopupWidth(double screenWidth) {
  if (screenWidth >= 1000) return screenWidth * 0.30;
  if (screenWidth >= 600) return screenWidth * 0.40;
  return screenWidth * 0.75;
}

/// 通用悬浮窗容器。
///
/// 统一圆角、阴影、背景色、裁剪与宽度档位。所有弹出菜单 / 面板都套这一层，
/// 保证不同页面弹出来的窗口是同一套外观与尺寸。
///
/// 宽度默认取 [appPopupWidth] 的档位值（窄屏 75% / 宽屏 40% / 超宽屏 30%），
/// 个别悬浮窗确实需要特殊宽度时传 [width] 自定义；无论哪种都不会超过屏幕宽度。
class AppPopup extends StatelessWidget {
  final Widget child;

  final EdgeInsetsGeometry padding;

  /// 阴影高度，默认与既有菜单一致（8）。
  final double elevation;

  /// 自定义宽度；为空时按屏幕档位取宽（推荐保持为空，统一外观）。
  final double? width;

  const AppPopup({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.elevation = 8,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final popupWidth =
        (width ?? appPopupWidth(screenWidth)).clamp(0.0, screenWidth);
    return SizedBox(
      width: popupWidth,
      child: Material(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(12),
        elevation: elevation,
        clipBehavior: Clip.antiAlias,
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
/// - [offset] 在定位结果上再平移一段距离（例如侧边栏要贴到屏幕左上角）；
/// - [transitionBuilder] 可替换默认的淡入缩放动画（例如侧边栏用左滑）；
/// - 返回点击项通过 `Navigator.pop(value)` 传出的值。
Future<T?> showAppPopup<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  GlobalKey? anchorKey,
  AppPopupPlacement placement = AppPopupPlacement.below,
  double gap = 6,
  Offset offset = Offset.zero,
  bool barrierDismissible = true,
  Color barrierColor = Colors.transparent,
  RouteTransitionsBuilder? transitionBuilder,
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
    barrierColor: barrierColor,
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
                  placement: placement,
                  offset: offset,
                ),
                child: builder(dialogContext),
              ),
            ),
        ],
      );
    },
    transitionBuilder: transitionBuilder ??
        (dialogContext, animation, secondaryAnimation, child) {
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
    required this.placement,
    this.offset = Offset.zero,
  });

  final Rect anchorRect;
  final double gap;
  final AppPopupPlacement placement;

  /// 在最终位置上追加的平移量（仍会经过屏幕边界夹紧）。
  final Offset offset;

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
    // 垂直于弹出方向的那一轴，默认与锚点居中对齐；
    // 居中后越界时才在下方统一夹紧，相当于自动平移。
    final centerX = anchorRect.center.dx - childSize.width / 2;
    final centerY = anchorRect.center.dy - childSize.height / 2;
    switch (chosen) {
      case AppPopupPlacement.below:
        left = centerX;
        top = anchorRect.bottom + gap;
        break;
      case AppPopupPlacement.above:
        left = centerX;
        top = anchorRect.top - gap - childSize.height;
        break;
      case AppPopupPlacement.right:
        left = anchorRect.right + gap;
        top = centerY;
        break;
      case AppPopupPlacement.left:
        left = anchorRect.left - gap - childSize.width;
        top = centerY;
        break;
    }

    final maxLeft = size.width - childSize.width - _margin;
    final maxTop = size.height - childSize.height - _margin;
    final limitLeft = maxLeft < _margin ? _margin : maxLeft;
    final limitTop = maxTop < _margin ? _margin : maxTop;

    double clampX(double value) => value.clamp(_margin, limitLeft).toDouble();
    double clampY(double value) => value.clamp(_margin, limitTop).toDouble();

    // 先夹紧居中结果，再叠加自定义偏移，最后再夹一次确保不出屏。
    left = clampX(left);
    top = clampY(top);
    left = clampX(left + offset.dx);
    top = clampY(top + offset.dy);
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_AnchorPopupLayout oldDelegate) =>
      anchorRect != oldDelegate.anchorRect ||
      gap != oldDelegate.gap ||
      placement != oldDelegate.placement ||
      offset != oldDelegate.offset;
}
