import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 通用悬浮窗默认最大宽度（菜单 / 面板不再按屏幕档位强制取宽）。
///
/// 宽度由内容决定，最多到 [defaultAppPopupWidth]；只有侧边栏保留
/// 「窄屏 75% / 宽屏 40% / 超宽屏 30%」的宽度档位。
const double defaultAppPopupWidth = 240;

/// 通用悬浮窗容器。
///
/// 统一圆角、阴影、背景色与裁剪。所有弹出菜单 / 面板都套这一层，
/// 保证不同页面弹出来的窗口是同一套外观。
///
/// 默认宽度由内容决定，最大不超过 [defaultAppPopupWidth]；个别悬浮窗
/// 需要固定 / 特殊宽度时传 [width]；任何情况下都不会超过屏幕宽度。
class AppPopup extends StatelessWidget {
  final Widget child;

  final EdgeInsetsGeometry padding;

  /// 阴影高度，默认与既有菜单一致（8）。
  final double elevation;

  /// 自定义固定宽度；为空时宽度由内容决定（最大 [defaultAppPopupWidth]）。
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
    final maxWidth = (width ?? defaultAppPopupWidth).clamp(0.0, screenWidth);
    final content = Material(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: elevation,
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
    if (width != null) {
      return SizedBox(width: maxWidth, child: content);
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: content,
    );
  }
}

/// 悬浮窗相对锚点的弹出方向。
enum AppPopupPlacement { below, above, left, right }

/// 以 [anchorKey] 对应的控件为锚点弹出悬浮窗，点击空白处关闭。
///
/// - [placement] 指定相对锚点的方向（上/下/左/右），默认在下方；
/// - 首选方向放不下时自动换到对侧或其它方向；[autoFlip] 为 false 时
///   始终保持首选方向（空间不足由边界夹紧处理）；
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
  bool autoFlip = true,
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
                  autoFlip: autoFlip,
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
    required this.autoFlip,
    this.offset = Offset.zero,
  });

  final Rect anchorRect;
  final double gap;
  final AppPopupPlacement placement;

  /// 是否允许放不下时切换到其它方向。
  final bool autoFlip;

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
    if (autoFlip && !fits(placement)) {
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
      autoFlip != oldDelegate.autoFlip ||
      offset != oldDelegate.offset;
}
