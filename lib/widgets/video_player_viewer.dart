import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/file_item.dart';
import '../providers/api_provider.dart';

/// 视频播放器页面。
///
/// 打开时默认「竖屏、非全屏」：页面保留顶部返回栏，视频按原始比例居中显示，
/// 点右下角全屏按钮才进入横屏沉浸式播放。
///
/// 操作逻辑仿 B 站：
/// - 单击视频画面：显示 / 隐藏控制层（播放中 3 秒自动隐藏）
/// - 双击视频画面：播放 / 暂停
/// - 左右滑动：快进 / 快退，并显示目标时间
/// - 左侧上下滑动：调节亮度；右侧上下滑动：调节音量
/// - 全屏模式下可锁定画面，锁定后仅保留解锁按钮
class VideoPlayerViewer extends ConsumerStatefulWidget {
  final FileItem file;

  const VideoPlayerViewer({super.key, required this.file});

  @override
  ConsumerState<VideoPlayerViewer> createState() => _VideoPlayerViewerState();
}

class _VideoPlayerViewerState extends ConsumerState<VideoPlayerViewer> {
  VideoPlayerController? _controller;

  bool _loading = true;
  String? _errorMessage;

  bool _fullscreen = false;
  bool _controlsVisible = true;
  bool _locked = false;

  double _volume = 1.0;
  double _brightness = 1.0;
  double _playbackSpeed = 1.0;

  Timer? _hideTimer;
  Timer? _hudTimer;

  bool _wasPlaying = false;

  // 底部进度条拖动状态。
  bool _draggingProgress = false;
  Duration? _dragPosition;

  // 视频画面手势状态。
  Duration _dragStartPosition = Duration.zero;
  Duration _seekPreview = Duration.zero;
  bool _showSeekHud = false;
  bool _showVolumeHud = false;
  bool _showBrightnessHud = false;
  bool _verticalIsBrightness = false;
  double? _verticalStartValue;
  Offset? _horizontalStartLocal;
  Offset? _verticalStartLocal;
  Size _gestureSize = Size.zero;

  bool get _ready =>
      _controller != null && _controller!.value.isInitialized;

  double get _aspectRatio {
    final c = _controller;
    if (c != null && c.value.isInitialized && c.value.aspectRatio > 0) {
      return c.value.aspectRatio;
    }
    return 16 / 9;
  }

  bool get _isPlaying => _controller?.value.isPlaying ?? false;

  bool get _hasPlaybackError =>
      _errorMessage != null ||
      (_ready && _controller!.value.hasError);

  @override
  void initState() {
    super.initState();
    // 打开播放器默认竖屏、非全屏；退出页面时恢复。
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _load();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _hudTimer?.cancel();
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _load() async {
    final old = _controller;
    _controller = null;
    old?.removeListener(_onControllerUpdate);
    await old?.dispose();
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(apiProvider);
      final url = await api.getFileSourceUrl(widget.file.path);
      if (url == null || url.isEmpty) {
        throw Exception('获取视频播放链接失败');
      }
      final absolute = _absoluteUrl(url, api.site?.normalizedBaseUrl ?? '');
      final controller =
          VideoPlayerController.networkUrl(Uri.parse(absolute));
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(_onControllerUpdate);
      await controller.setVolume(_volume);
      await controller.setPlaybackSpeed(_playbackSpeed);
      setState(() {
        _controller = controller;
        _loading = false;
      });
      controller.play();
      _showControls();
    } catch (e) {
      print('[VideoPlayerViewer] 加载失败: ${widget.file.name} -> $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  /// 直链是相对路径时补全站点地址。
  String _absoluteUrl(String url, String base) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    if (url.startsWith('/')) return '$b$url';
    return '$b/$url';
  }

  void _onControllerUpdate() {
    final c = _controller;
    final playing = c?.value.isPlaying ?? false;
    // 播放状态由暂停转为播放时，重新计时隐藏控制层。
    if (playing && !_wasPlaying && _controlsVisible) {
      _scheduleAutoHide();
    }
    // 播放结束后重新浮现控制层，便于重播。
    final ended = c != null &&
        c.value.isInitialized &&
        !c.value.hasError &&
        c.value.duration > Duration.zero &&
        c.value.position >= c.value.duration &&
        !playing;
    if (ended && !_controlsVisible) {
      _showControls();
      return;
    }
    _wasPlaying = playing;
    if (!mounted) return;
    setState(() {});
  }

  // ---------- 控制层显隐 ----------

  void _showControls() {
    _hideTimer?.cancel();
    if (!mounted) return;
    setState(() => _controlsVisible = true);
    _scheduleAutoHide();
  }

  void _hideControls() {
    _hideTimer?.cancel();
    if (!mounted) return;
    setState(() => _controlsVisible = false);
  }

  void _scheduleAutoHide() {
    _hideTimer?.cancel();
    if (!_isPlaying || !_controlsVisible) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || _draggingProgress) return;
      setState(() => _controlsVisible = false);
    });
  }

  void _handleTap() {
    if (_controlsVisible) {
      _hideControls();
    } else {
      _showControls();
    }
  }

  void _handleDoubleTap() {
    if (_locked) return;
    _togglePlay();
  }

  // ---------- 播放控制 ----------

  void _togglePlay() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
      _hideTimer?.cancel(); // 暂停时控制层常驻。
    } else {
      c.play();
      _showControls();
    }
    setState(() {});
  }

  Future<void> _toggleFullscreen() async {
    setState(() => _fullscreen = !_fullscreen);
    if (_fullscreen) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations(
          const [DeviceOrientation.portraitUp]);
    }
    _showControls();
  }

  void _toggleLock() {
    setState(() => _locked = !_locked);
    if (_locked) {
      _hideControls();
    } else {
      _showControls();
    }
  }

  Future<void> _showSpeedMenu() async {
    _hideTimer?.cancel();
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    // 横屏全屏时底部弹层高度受限，改用居中面板避免超出屏幕。
    final double? selected = _fullscreen
        ? await showDialog<double>(
            context: context,
            builder: (context) =>
                _buildFullscreenSpeedPanel(context, speeds),
          )
        : await showModalBottomSheet<double>(
            context: context,
            backgroundColor: const Color(0xFF1F1F1F),
            builder: (context) {
              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        '倍速播放',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    for (final speed in speeds)
                      ListTile(
                        leading: speed == _playbackSpeed
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 20)
                            : const SizedBox(width: 20),
                        title: Text(
                          speed == 1.0 ? '1.0x' : '${speed}x',
                          style: TextStyle(
                            color: speed == _playbackSpeed
                                ? Theme.of(context).colorScheme.primary
                                : Colors.white,
                          ),
                        ),
                        onTap: () => Navigator.of(context).pop(speed),
                      ),
                  ],
                ),
              );
            },
          );
    if (selected == null || !mounted) {
      _scheduleAutoHide();
      return;
    }
    setState(() => _playbackSpeed = selected);
    await _controller?.setPlaybackSpeed(selected);
    _scheduleAutoHide();
  }

  /// 横屏全屏用的倍速面板：两列网格，宽度/高度都受屏幕约束并可滚动。
  Widget _buildFullscreenSpeedPanel(BuildContext context, List<double> speeds) {
    final size = MediaQuery.of(context).size;
    return SafeArea(
      child: Center(
        child: Material(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: size.width * 0.55,
              maxHeight: size.height * 0.9,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Text(
                      '倍速播放',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 0,
                    crossAxisSpacing: 0,
                    childAspectRatio: 2.8,
                    children: [
                      for (final speed in speeds)
                        InkWell(
                          onTap: () => Navigator.of(context).pop(speed),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (speed == _playbackSpeed)
                                const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 18)
                              else
                                const SizedBox(width: 18),
                              const SizedBox(width: 8),
                              Text(
                                speed == 1.0 ? '1.0x' : '${speed}x',
                                style: TextStyle(
                                  color: speed == _playbackSpeed
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- 画面手势（仿 B 站） ----------

  void _onHorizontalDragStart(DragStartDetails details) {
    if (_locked || !_ready) return;
    final c = _controller!;
    _dragStartPosition = c.value.position;
    _horizontalStartLocal = details.localPosition;
    setState(() {
      _seekPreview = _dragStartPosition;
      _showSeekHud = true;
      _showVolumeHud = false;
      _showBrightnessHud = false;
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final start = _horizontalStartLocal;
    if (_locked || !_showSeekHud || start == null) return;
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final total = c.value.duration.inMilliseconds;
    final width = _gestureSize.width > 0
        ? _gestureSize.width
        : MediaQuery.of(context).size.width;
    if (total <= 0 || width <= 0) return;
    // 使用相对起点的累计位移，一次连续滑动即可大范围快进 / 快退。
    final travelled = details.localPosition.dx - start.dx;
    final deltaMs = travelled / width * total;
    final target = (_dragStartPosition.inMilliseconds + deltaMs)
        .round()
        .clamp(0, total)
        .toInt();
    setState(() => _seekPreview = Duration(milliseconds: target));
    _flashHud();
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_showSeekHud) return;
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      c.seekTo(_seekPreview);
    }
    _horizontalStartLocal = null;
    _flashHud();
  }

  void _onVerticalDragStart(DragStartDetails details) {
    if (_locked || !_ready) return;
    final width = MediaQuery.of(context).size.width;
    _verticalIsBrightness = details.globalPosition.dx < width / 2;
    _verticalStartValue = _verticalIsBrightness ? _brightness : _volume;
    _verticalStartLocal = details.localPosition;
    setState(() {
      _showBrightnessHud = _verticalIsBrightness;
      _showVolumeHud = !_verticalIsBrightness;
      _showSeekHud = false;
    });
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    final start = _verticalStartLocal;
    final startValue = _verticalStartValue;
    if (_locked || start == null || startValue == null) return;
    final height = _gestureSize.height > 0
        ? _gestureSize.height
        : MediaQuery.of(context).size.height;
    if (height <= 0) return;
    // 相对起点累计位移：上滑增大、下滑减小，滑满画面高度对应 0-100。
    final travelled = details.localPosition.dy - start.dy;
    final delta = -travelled / height;
    final value = (startValue + delta).clamp(0.0, 1.0).toDouble();
    final changed =
        _verticalIsBrightness ? _brightness != value : _volume != value;
    setState(() {
      if (_verticalIsBrightness) {
        _brightness = value;
      } else {
        _volume = value;
      }
    });
    if (!_verticalIsBrightness && changed) {
      _controller?.setVolume(_volume);
    }
    _flashHud();
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    _verticalStartLocal = null;
    _verticalStartValue = null;
    _flashHud();
  }

  void _flashHud() {
    _hudTimer?.cancel();
    _hudTimer = Timer(const Duration(milliseconds: 700), _clearGestureHud);
  }

  void _clearGestureHud() {
    if (!mounted) return;
    setState(() {
      _showSeekHud = false;
      _showVolumeHud = false;
      _showBrightnessHud = false;
    });
  }

  // ---------- 进度条 ----------

  double _progressFraction() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return 0;
    final total = c.value.duration.inMilliseconds;
    if (total <= 0) return 0;
    final currentMs = (_dragPosition ?? c.value.position).inMilliseconds;
    return (currentMs / total).clamp(0.0, 1.0).toDouble();
  }

  double _bufferedFraction() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return 0;
    final total = c.value.duration.inMilliseconds;
    final ranges = c.value.buffered;
    if (total <= 0 || ranges.isEmpty) return 0;
    return (ranges.last.end.inMilliseconds / total).clamp(0.0, 1.0).toDouble();
  }

  void _seekToFraction(double dx, double width, {bool commit = true}) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final total = c.value.duration.inMilliseconds;
    if (total <= 0 || width <= 0) return;
    final ms = (dx / width * total).round().clamp(0, total).toInt();
    if (commit) {
      c.seekTo(Duration(milliseconds: ms));
    } else {
      setState(() => _dragPosition = Duration(milliseconds: ms));
    }
  }

  void _commitProgressDrag() {
    final c = _controller;
    final target = _dragPosition;
    if (c != null && c.value.isInitialized && target != null) {
      c.seekTo(target);
    }
    if (!mounted) return;
    setState(() {
      _draggingProgress = false;
      _dragPosition = null;
    });
    _scheduleAutoHide();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  // ---------- 界面 ----------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_fullscreen,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // 全屏时返回键先退出全屏。
        if (_fullscreen) {
          _toggleFullscreen();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _fullscreen ? _buildFullscreen() : _buildPortrait(),
      ),
    );
  }

  /// 竖屏非全屏：顶部返回栏 + 居中视频区，控制栏固定屏幕最底部。
  Widget _buildPortrait() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
            _buildPageTopBar(),
            Expanded(
              child: Center(child: _buildVideoSurface()),
            ),
          ],
        ),
        _buildControls(),
      ],
    );
  }

  /// 横屏沉浸式全屏：视频居中，控制层铺满整个屏幕；
  /// 另加一层铺满黑边的手势层，保证黑边区域也能滑动 / 点击。
  Widget _buildFullscreen() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 黑边手势层：Center 未命中的区域（上下/左右黑边）也能操作。
        _buildGestureLayer(),
        Center(child: _buildVideoSurface()),
        _buildControls(),
      ],
    );
  }

  Widget _buildPageTopBar() {
    return Container(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              IconButton(
                tooltip: '返回',
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text(
                  widget.file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// 视频画面本体 + 画面内交互层（手势 / 加载 / 错误 / HUD / 中央播放键）。
  Widget _buildVideoSurface() {
    return AspectRatio(
      aspectRatio: _aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildVideoLayer(),
          _buildGestureLayer(),
          if (_loading)
            const Center(
                child: CircularProgressIndicator(color: Colors.white)),
          if (!_loading && _hasPlaybackError) _buildErrorView(),
          _buildGestureHud(),
          _buildCenterPlayButton(),
        ],
      ),
    );
  }

  Widget _buildVideoLayer() {
    final c = _controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (c != null && c.value.isInitialized)
          VideoPlayer(c)
        else
          Container(color: Colors.black),
        // 亮度降低时叠加一层黑色遮罩。
        if (_brightness < 1.0)
          IgnorePointer(
            child: Container(
              color: Colors.black.withOpacity(
                  ((1 - _brightness) * 0.85).clamp(0.0, 0.85).toDouble()),
            ),
          ),
      ],
    );
  }

  Widget _buildGestureLayer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 记录手势区域实际尺寸，作为滑动调节的满量程基准。
        _gestureSize = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _handleTap,
          onDoubleTap: _handleDoubleTap,
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          onHorizontalDragCancel: () {
            _horizontalStartLocal = null;
            _verticalStartLocal = null;
            _verticalStartValue = null;
            _clearGestureHud();
          },
          onVerticalDragStart: _onVerticalDragStart,
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          onVerticalDragCancel: () {
            _verticalStartLocal = null;
            _verticalStartValue = null;
            _clearGestureHud();
          },
          child: const SizedBox.expand(),
        );
      },
    );
  }

  Widget _buildErrorView() {
    final detail = _controller?.value.errorDescription ?? _errorMessage ?? '';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white70, size: 48),
            const SizedBox(height: 12),
            const Text(
              '视频加载失败',
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text('重试',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGestureHud() {
    final Widget child;
    if (_showSeekHud) {
      final total = _controller?.value.duration ?? Duration.zero;
      final forward = _seekPreview >= _dragStartPosition;
      child = _hudBox(
        icon: Icon(
          forward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
          color: Colors.white,
          size: 28,
        ),
        label: '${_fmt(_seekPreview)} / ${_fmt(total)}',
      );
    } else if (_showBrightnessHud) {
      child = _hudBox(
        icon: const Icon(Icons.brightness_6_rounded,
            color: Colors.white, size: 28),
        label: '亮度 ${(_brightness * 100).round()}%',
      );
    } else if (_showVolumeHud) {
      child = _hudBox(
        icon:
            const Icon(Icons.volume_up_rounded, color: Colors.white, size: 28),
        label: '音量 ${(_volume * 100).round()}%',
      );
    } else {
      child = const SizedBox.shrink();
    }
    return Center(child: child);
  }

  Widget _hudBox({required Widget icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xB3000000),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCenterPlayButton() {
    final show = _ready && !_isPlaying && _controlsVisible;
    return Center(
      child: IgnorePointer(
        ignoring: !show,
        child: AnimatedOpacity(
          opacity: show ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: IconButton(
            tooltip: '播放',
            iconSize: 72,
            icon: const Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white,
            ),
            onPressed: _togglePlay,
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    final show = _controlsVisible;
    return IgnorePointer(
      ignoring: !show,
      child: AnimatedOpacity(
        opacity: show ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        child: _locked ? _buildLockedControls() : _buildNormalControls(),
      ),
    );
  }

  Widget _buildLockedControls() {
    return Center(
      child: IconButton(
        tooltip: '解锁',
        iconSize: 40,
        icon: const Icon(Icons.lock_open_rounded, color: Colors.white),
        onPressed: _toggleLock,
      ),
    );
  }

  Widget _buildNormalControls() {
    if (_fullscreen) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildFullscreenTopBar(),
          _buildBottomBar(),
        ],
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [_buildBottomBar()],
    );
  }

  Widget _buildFullscreenTopBar() {
    final safe = MediaQuery.of(context).padding;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xB3000000), Color(0x66000000), Colors.transparent],
        ),
      ),
      padding: EdgeInsets.only(
        top: 12 + safe.top,
        bottom: 20,
        left: 4 + safe.left,
        right: 4 + safe.right,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: '退出全屏',
            icon: const Icon(Icons.fullscreen_exit_rounded,
                color: Colors.white),
            onPressed: _toggleFullscreen,
          ),
          Expanded(
            child: Text(
              widget.file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
          IconButton(
            tooltip: _locked ? '解锁' : '锁定画面',
            icon: Icon(
              _locked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
              color: Colors.white,
            ),
            onPressed: _toggleLock,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final duration = _controller?.value.duration ?? Duration.zero;
    final position = _dragPosition ?? _controller?.value.position ?? Duration.zero;
    final safe = MediaQuery.of(context).padding;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xB3000000), Color(0x66000000), Colors.transparent],
        ),
      ),
      padding: EdgeInsets.only(
        left: 8 + safe.left,
        right: 8 + safe.right,
        top: 28,
        bottom: (_fullscreen ? 6 : 10) + safe.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildProgressBar(),
          Row(
            children: [
              IconButton(
                tooltip: _isPlaying ? '暂停' : '播放',
                icon: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: _ready ? _togglePlay : null,
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(44, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _showSpeedMenu,
                child: Text(
                  _playbackSpeed == 1.0 ? '倍速' : '${_playbackSpeed}x',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Text(
                '${_fmt(position)} / ${_fmt(duration)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const Spacer(),
              IconButton(
                tooltip: _fullscreen ? '退出全屏' : '全屏',
                icon: Icon(
                  _fullscreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  color: Colors.white,
                ),
                onPressed: _toggleFullscreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final primary = Theme.of(context).colorScheme.primary;
    final progress = _progressFraction();
    final buffered = _bufferedFraction();
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        double px(double f) => (f * w).clamp(0.0, w).toDouble();
        final thumbSize = _draggingProgress ? 14.0 : 11.0;
        final thumbLeft =
            (px(progress) - thumbSize / 2).clamp(0.0, w - thumbSize);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _seekToFraction(d.localPosition.dx, w),
          onHorizontalDragStart: (d) {
            _hideTimer?.cancel();
            setState(() => _draggingProgress = true);
            _seekToFraction(d.localPosition.dx, w, commit: false);
          },
          onHorizontalDragUpdate: (d) =>
              _seekToFraction(d.localPosition.dx, w, commit: false),
          onHorizontalDragEnd: (_) => _commitProgressDrag(),
          onHorizontalDragCancel: () {
            if (!mounted) return;
            setState(() {
              _draggingProgress = false;
              _dragPosition = null;
            });
            _scheduleAutoHide();
          },
          child: SizedBox(
            height: 36,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // 轨道。
                Container(
                  height: 3,
                  width: w,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 已缓冲段。
                Container(
                  height: 3,
                  width: px(buffered),
                  color: Colors.white38,
                ),
                // 已播放段（站点主题色）。
                Container(
                  height: 3,
                  width: px(progress),
                  color: primary,
                ),
                // 拖动圆点。
                Positioned(
                  left: thumbLeft,
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
