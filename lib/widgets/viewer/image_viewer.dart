import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

import '../../core/image/image_loader.dart';
import '../../core/network/cloudreve_api.dart';
import '../../models/file_item.dart';
import '../../providers/api_provider.dart';
import '../sheet/file_info_sheet.dart';

/// 全屏图片浏览组件：纯黑背景，居中显示，左右滑动切换，
/// 左上角索引，右上角 X / 详情 / 下载。
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
  late int _index = widget.initialIndex;
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);

  /// 分享页传入自己的 api；主页走全局 provider。
  late final CloudreveApi _api = widget.api ?? ref.read(apiProvider);

  /// 当前页是否处于放大状态：放大时禁用翻页，手势改为拖拽平移图片。
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _prefetch(_index);
  }

  @override
  void dispose() {
    _controller.dispose();
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
  }

  void _handleZoomChanged(bool zoomed) {
    if (_zoomed == zoomed) return;
    setState(() => _zoomed = zoomed);
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.images[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            physics: _zoomed
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
        ],
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
        _toast('获取下载链接失败');
        return;
      }
      final resp = await _api.dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = resp.data;
      if (bytes == null || bytes.isEmpty) {
        _toast('下载失败');
        return;
      }
      await Gal.putImageBytes(Uint8List.fromList(bytes));
      _toast('已保存到相册');
    } catch (e) {
      print('[ImageViewer] 下载失败: ${file.path} -> $e');
      _toast('下载失败');
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
          const Text('无法加载图片', style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: const Text('重试', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
