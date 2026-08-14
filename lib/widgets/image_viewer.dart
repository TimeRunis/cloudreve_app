import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

import '../models/file_item.dart';
import '../providers/api_provider.dart';
import 'file_info_sheet.dart';

/// 全屏图片浏览组件：纯黑背景，居中显示，左右滑动切换，
/// 左上角索引，右上角 X / 详情 / 下载。
class ImageViewer extends ConsumerStatefulWidget {
  final List<FileItem> images;
  final int initialIndex;

  const ImageViewer({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  ConsumerState<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends ConsumerState<ImageViewer> {
  late int _index = widget.initialIndex;
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) =>
                _ImageViewerPage(file: widget.images[i]),
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
                  _transparentBtn(Icons.file_download_outlined,
                      () => _download(current)),
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
      builder: (_) => FileInfoSheet(file: file),
    );
  }

  Future<void> _download(FileItem file) async {
    try {
      final api = ref.read(apiProvider);
      final url = await api.getFileSourceUrl(file.path);
      if (url == null || url.isEmpty) {
        _toast('获取下载链接失败');
        return;
      }
      final resp = await api.dio.get<List<int>>(
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

/// 单张图片页：用 dio 下载字节后显示，下载过程展示进度。
class _ImageViewerPage extends ConsumerStatefulWidget {
  final FileItem file;

  const _ImageViewerPage({required this.file});

  @override
  ConsumerState<_ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends ConsumerState<_ImageViewerPage> {
  Uint8List? _bytes;
  double? _progress;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiProvider);
      final url = await api.getFileSourceUrl(widget.file.path);
      if (url == null || url.isEmpty) {
        print('[ImageViewer] 获取原图链接失败: ${widget.file.path}');
        if (mounted) setState(() => _failed = true);
        return;
      }
      final resp = await api.dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _progress = received / total);
          }
        },
      );
      final data = resp.data;
      if (data == null || data.isEmpty) {
        print('[ImageViewer] 图片内容为空: ${widget.file.path}');
        if (mounted) setState(() => _failed = true);
        return;
      }
      if (!mounted) return;
      setState(() => _bytes = Uint8List.fromList(data));
    } catch (e) {
      print('[ImageViewer] 加载图片失败: ${widget.file.path} -> $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const _ImageViewerError();
    final bytes = _bytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return Center(
      child: CircularProgressIndicator(color: Colors.white, value: _progress),
    );
  }
}

class _ImageViewerError extends StatelessWidget {
  const _ImageViewerError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
          SizedBox(height: 8),
          Text('无法加载图片', style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}
