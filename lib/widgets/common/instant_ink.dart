import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 立即出水波纹的点击区域。
///
/// 只要给 [InkWell] 设置了 `onDoubleTap`，点击就必须等手势竞技场结算
/// （双击超时，约 300ms）才会触发 `onTapDown`，墨水扩散因此明显滞后；
/// 没设双击的按钮则立刻扩散，手感不一致。
///
/// 这里把水波纹改成监听 PointerDown 后直接画到最近的 [Material] 上，
/// 点击 / 双击 / 长按仍交给 [GestureDetector] 识别，行为与 InkWell 一致。
class InstantInk extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;

  const InstantInk({
    super.key,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
  });

  @override
  State<InstantInk> createState() => _InstantInkState();
}

class _InstantInkState extends State<InstantInk> {
  InteractiveInkFeature? _splash;

  /// 按下位置：移动超过滑动阈值就取消水波纹（避免滚动时留下水花）。
  Offset? _downPosition;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: (_) => _confirmSplash(),
      onPointerCancel: (_) => _cancelSplash(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onLongPress: widget.onLongPress,
        child: widget.child,
      ),
    );
  }

  @override
  void dispose() {
    _cancelSplash();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    _cancelSplash();
    _downPosition = event.position;
    final material = Material.maybeOf(context);
    final box = context.findRenderObject();
    if (material == null || box is! RenderBox || !box.hasSize) return;
    _splash = Theme.of(context).splashFactory.create(
          controller: material,
          referenceBox: box,
          position: box.globalToLocal(event.position),
          // 与 InkWell 的取色逻辑保持一致。
          color: Theme.of(context).splashColor,
          textDirection: Directionality.of(context),
          containedInkWell: true,
          rectCallback: () => Offset.zero & box.size,
        );
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final down = _downPosition;
    if (down == null) return;
    if ((event.position - down).distance <= kTouchSlop) return;
    _downPosition = null;
    _cancelSplash();
  }

  void _confirmSplash() {
    _downPosition = null;
    _splash?.confirm();
    _splash = null;
  }

  void _cancelSplash() {
    _splash?.cancel();
    _splash = null;
  }
}
