import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

import '../../core/image/image_loader.dart';
import '../../core/network/cloudreve_api.dart';
import '../../models/file_item.dart';
import '../../providers/api_provider.dart';
import '../file/file_thumbnail.dart';
import '../sheet/file_info_sheet.dart';
import '../../core/i18n/app_localizations.dart';

/// 全屏图片浏览组件：纯黑背景，居中显示，左右滑动切换，
/// 左上角索引，右上角 X / 详情 / 下载，底部一条可横向滚动的缩略图长条。
///
/// 图片统一走 [ImageLoader]：内存缓存 + 最多 5 张并发 + 滑走后台继续加载，
/// 打开时预取前后各一张。
///
/// 支持双指 / 鼠标滚轮缩放、双击放大还原、放大后拖拽平移；
/// 放大期间会临时禁用左右翻页，避免拖拽图片时误切页。
class ImageViewer extends ConsumerStatefulWidget {
  final List<FileItem> images;
  final int initialIndex;
  final CloudreveApi? api;

  const ImageViewer({
    super.key,
    required this.images,
    required this.initialIndex,
    this.api,
  });

  @override
  ConsumerState<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends ConsumerState<ImageViewer> {
  /// 底部缩略图边长。
  static const double _thumbSize = 52;

  /// 缩略图之间的间距。
  static const double _thumbGap = 6;

  /// 单个缩略图在横向列表里占的宽度（含间距）。
  static const double _thumbExtent = _thumbSize + _thumbGap;

  /// 缩略图列表左右留白。
  static const double _thumbPadding = 8;

  /// 缩略图长条高度（含上下留白）。
  static const double _thumbStripHeight = _thumbSize + 20;

  late int _index = widget.initialIndex;
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);

  /// 底部缩略图长条的水平滚动控制器。
  late final ScrollController _thumbController;

  /// 是否已经按初始索引算好缩略图长条的起始位置。
  bool _thumbControllerReady = false;

  /// 分享页传入自己的 api；主页走全局 provider。
  late final CloudreveApi _api = widget.api ?? ref.read(apiProvider);

  /// 当前页是否处于放大状态：放大时禁用翻页，手势改为拖拽平移图片。
  bool _zoomed = false;

  /// 当前按在画面上的手指数：≥2 时视为双指缩放，立即锁定翻页。
  int _activePointers = 0;

  /// 是否锁定左右翻页：放大中，或正在双指操作。
  bool get _pageLocked => _zoomed || _activePointers > 1;

  @override
  void initState() {
    super.initState();
    _prefetch(_index);
    // 首帧布局完成后把当前图片的缩略图滚到长条中间。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerThumbnail(_index, animate: false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_thumbControllerReady) return;
    _thumbControllerReady = true;
    // 先按屏幕宽度算好居中位置，避免首帧从第一张闪到当前图片。
    final width = MediaQuery.sizeOf(context).width;
    final offset = _thumbPadding +
        widget.initialIndex * _thumbExtent -
        (width - _thumbExtent) / 2;
    _thumbController = ScrollController(
      initialScrollOffset: offset < 0 ? 0 : offset,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _thumbController.dispose();
    super.dispose();
  }

  /// 预取前后各一张：只排进加载队列，不阻塞当前页显示。
  void _prefetch(int index) {
    for (var i = index - 1; i <= index + 1; i++) {
      if (i < 0 || i >= widget.images.length) continue;
      requestCloudreveImage(_api, widget.images[i]);
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _index = index;
      _zoomed = false;
    });
    _prefetch(index);
    _centerThumbnail(index);
  }

  /// 把第 [index] 张缩略图滚到长条中间；[animate] 为 false 时直接定位。
  void _centerThumbnail(int index, {bool animate = true}) {
    if (!_thumbController.hasClients) return;
    final position = _thumbController.position;
    final target = _thumbPadding +
        index * _thumbExtent -
        (position.viewportDimension - _thumbExtent) / 2;
    final clamped = target.clamp(0.0, position.maxScrollExtent).toDouble();
    if (!animate) {
      _thumbController.jumpTo(clamped);
      return;
    }
    _thumbController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  /// 点击底部缩略图：切到对应图片。
  void _selectIndex(int index) {
    if (index == _index || !_controller.hasClients) return;
    // 跨很多张时直接跳，避免 PageView 一路翻页造成卡顿和闪烁。
    if ((index - _index).abs() > 3) {
      _controller.jumpToPage(index);
      return;
    }
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleZoomChanged(bool zoomed) {
    if (_zoomed == zoomed) return;
    setState(() => _zoomed = zoomed);
  }

  /// 手指数变化：第二根手指落下的瞬间就禁用翻页，
  /// 否则双指捏合时第一根手指移动超过触发阈值会被 PageView 当成翻页。
  void _handlePointerCount(int delta) {
    final next = (_activePointers + delta).clamp(0, 10);
    if (next == _activePointers) return;
    final wasLocked = _pageLocked;
    _activePointers = next;
    final locked = _pageLocked;
    if (wasLocked == locked) return;
    setState(() {});
    if (locked) _snapToNearestPage();
  }

  /// 锁定翻页时如果页面停在两页之间，等重建完成后吸附到最近的一页。
  void _snapToNearestPage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final page = _controller.page;
      if (page == null) return;
      final nearest = page.roundToDouble();
      if ((page - nearest).abs() > 0.01) {
        _controller.jumpToPage(nearest.toInt());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.images[_index];
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _handlePointerCount(1),
      onPointerUp: (_) => _handlePointerCount(-1),
      onPointerCancel: (_) => _handlePointerCount(-1),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              physics: _pageLocked
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              itemCount: widget.images.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, i) => _ImageViewerPage(
                file: widget.images[i],
                api: _api,
                onZoomChanged: _handleZoomChanged,
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      '${_index + 1} / ${widget.images.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const Spacer(),
                    _transparentBtn(
                        Icons.close, () => Navigator.of(context).pop()),
                    _transparentBtn(
                        Icons.info_outline, () => _showDetail(current)),
                    _transparentBtn(
                        Icons.file_download_outlined, () => _download(current)),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildThumbnailStrip(),
            ),
          ],
        ),
      ),
    );
  }

  /// 底部缩略图长条：横向滚动展示当前文件夹所有图片，点击可切换。
  Widget _buildThumbnailStrip() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.72),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _thumbStripHeight,
          child: ListView.builder(
            controller: _thumbController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: _thumbPadding,
              vertical: 10,
            ),
            itemExtent: _thumbExtent,
            itemCount: widget.images.length,
            itemBuilder: (context, i) {
              final selected = i == _index;
              return Padding(
                padding: const EdgeInsets.only(right: _thumbGap),
                child: GestureDetector(
                  key: ValueKey('viewer-thumb-$i'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _selectIndex(i),
                  child: SizedBox(
                    width: _thumbSize,
                    height: _thumbSize,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected ? Colors.white : Colors.white24,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: FileThumbnail(
                          file: widget.images[i],
                          size: _thumbSize - 4,
                          api: widget.api,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _transparentBtn(IconData icon, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: Colors.white),
      onPressed: onTap,
    );
  }

  void _showDetail(FileItem file) {
    showModalBottomSheet(
      context: context,
      builder: (_) => FileInfoSheet(file: file, api: widget.api),
    );
  }

  Future<void> _download(FileItem file) async {
    try {
      final url = await _api.getFileSourceUrl(file.path);
      if (url == null || url.isEmpty) {
        _toast(tr('获取下载链接失败'));
        return;
      }
      final resp = await _api.dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = resp.data;
      if (bytes == null || bytes.isEmpty) {
        _toast(tr('下载失败'));
        return;
      }
      await Gal.putImageBytes(Uint8List.fromList(bytes));
      _toast(tr('已保存到相册'));
    } catch (e) {
      print('[ImageViewer] 下载失败: ${file.path} -> $e');
      _toast(tr('下载失败'));
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// 单张图片页：从 [ImageLoader] 取图（缓存 + 后台加载 + 并发上限），
/// 下载过程展示进度，失败可重试。
///
/// 加载完成后可缩放：双指 / 鼠标滚轮缩放、双击放大还原、放大后拖拽平移。
class _ImageViewerPage extends ConsumerStatefulWidget {
  final FileItem file;
  final CloudreveApi? api;

  /// 放大状态变化：父级据此临时禁用左右翻页。
  final ValueChanged<bool> onZoomChanged;

  const _ImageViewerPage({
    required this.file,
    required this.onZoomChanged,
    this.api,
  });

  @override
  ConsumerState<_ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends ConsumerState<_ImageViewerPage>
    with SingleTickerProviderStateMixin {
  /// 最大放大倍数。
  static const double _maxScale = 4;

  /// 双击放大到的倍数。
  static const double _doubleTapScale = 2.5;

  late final CloudreveApi _api = widget.api ?? ref.read(apiProvider);

  /// 缩放 / 平移矩阵。
  final TransformationController _transform = TransformationController();

  late final AnimationController _zoomAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  Animation<Matrix4>? _zoomTween;

  /// 最近一次双击的位置（局部坐标），用于以该点为中心放大。
  Offset? _doubleTapPosition;

  /// 当前是否已放大（避免重复通知父级）。
  bool _zoomed = false;

  ImageTask? _task;
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _start();
    _zoomAnimation.addListener(_applyZoomTween);
  }

  @override
  void dispose() {
    _zoomAnimation.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _start() {
    final task = requestCloudreveImage(_api, widget.file);
    _task = task;
    // 命中缓存：同步拿字节，避免再闪一次加载圈。
    if (task.isReady) {
      _bytes = task.bytes;
      return;
    }
    // 任务归加载器所有：本页被滑走销毁后下载仍会继续，完成后写入缓存。
    task.value.then(
      (bytes) {
        if (!mounted) return;
        setState(() => _bytes = bytes);
      },
      onError: (Object error) {
        debugPrint('[ImageViewer] 加载图片失败: ${widget.file.path} -> $error');
        if (!mounted) return;
        setState(() => _failed = true);
      },
    );
  }

  void _retry() {
    setState(() {
      _failed = false;
      _bytes = null;
    });
    _start();
  }

  /// 把放大状态同步给父级：只在跨过阈值时通知，避免每帧 setState。
  void _syncZoomState() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed == _zoomed) return;
    _zoomed = zoomed;
    widget.onZoomChanged(zoomed);
  }

  /// 双击：已放大则还原，否则以双击点为中心放大。
  void _handleDoubleTap() {
    if (_transform.value.getMaxScaleOnAxis() > 1.01) {
      _animateZoomTo(Matrix4.identity());
      return;
    }
    final size = context.size ?? MediaQuery.sizeOf(context);
    if (size.isEmpty) return;
    final focal = _doubleTapPosition ?? size.center(Offset.zero);
    _animateZoomTo(_zoomMatrixAt(focal, size, _doubleTapScale));
  }

  /// 以 [focal] 为中心缩放到 [scale]，并把平移量限制在图片边界内。
  Matrix4 _zoomMatrixAt(Offset focal, Size size, double scale) {
    // 缩放后左上角允许的平移范围是 [extent * (1 - scale), 0]。
    double clampAxis(double value, double extent) =>
        value.clamp(extent * (1 - scale), 0.0).toDouble();

    final dx = clampAxis(focal.dx * (1 - scale), size.width);
    final dy = clampAxis(focal.dy * (1 - scale), size.height);
    return Matrix4.identity()
      ..translate(dx, dy)
      ..scale(scale);
  }

  void _animateZoomTo(Matrix4 target) {
    _zoomTween = Matrix4Tween(begin: _transform.value, end: target).animate(
      CurvedAnimation(parent: _zoomAnimation, curve: Curves.easeOut),
    );
    _zoomAnimation.forward(from: 0);
  }

  void _applyZoomTween() {
    final tween = _zoomTween;
    if (tween == null) return;
    _transform.value = tween.value;
    _syncZoomState();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return _ImageViewerError(onRetry: _retry);
    final bytes = _bytes;
    if (bytes != null) {
      return GestureDetector(
        onDoubleTapDown: (details) =>
            _doubleTapPosition = details.localPosition,
        onDoubleTap: _handleDoubleTap,
        child: InteractiveViewer(
          transformationController: _transform,
          minScale: 1,
          maxScale: _maxScale,
          onInteractionEnd: (_) => _syncZoomState(),
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      );
    }
    final task = _task;
    if (task == null) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }
    return Center(
      child: ValueListenableBuilder<double?>(
        valueListenable: task.progress,
        builder: (context, progress, _) => CircularProgressIndicator(
          color: Colors.white,
          value: progress,
        ),
      ),
    );
  }
}

class _ImageViewerError extends StatelessWidget {
  final VoidCallback onRetry;

  const _ImageViewerError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined,
              color: Colors.white54, size: 48),
          const SizedBox(height: 8),
          Text(tr('无法加载图片'), style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: Text(tr('重试'), style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
