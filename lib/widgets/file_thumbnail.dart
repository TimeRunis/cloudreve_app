import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/cloudreve_api.dart';
import '../core/theme/app_colors.dart';
import '../models/file_item.dart';
import '../providers/directory_provider.dart';
import 'file_icon.dart';

/// 文件缩略图：图片/视频显示缩略图，其余显示图标。
///
/// [fill] 为 true 时，缩略图铺满父级可用空间（用于网格卡片顶部区域）。
class FileThumbnail extends ConsumerWidget {
  /// 分享页自定义 API 的缩略图 URL 内存缓存，避免每次 build 都重新请求直链。
  static final Map<String, Future<String?>> _thumbnailUrlCache = {};

  final FileItem file;
  final double size;
  final bool rounded;
  final bool fill;
  final CloudreveApi? api;

  const FileThumbnail({
    super.key,
    required this.file,
    this.size = 56,
    this.rounded = true,
    this.fill = false,
    this.api,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (file.isFolder || !hasThumbnail(file)) {
      return _icon(context);
    }
    final providedApi = api;
    if (providedApi != null) {
      final cacheKey =
          '${providedApi.site?.normalizedBaseUrl}|${file.path}';
      final future = _thumbnailUrlCache.putIfAbsent(
        cacheKey,
        () => providedApi.getThumbnailUrl(
          file.path,
          width: 320,
          height: 320,
        ),
      );
      return FutureBuilder<String?>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _SkeletonBox(size: size, fill: fill);
          }
          if (snapshot.hasError) return _icon(context);
          final url = snapshot.data;
          if (url == null || url.isEmpty) return _icon(context);
          return _buildImage(context, url);
        },
      );
    }
    final thumbAsync = ref.watch(thumbnailUrlProvider(file.path));
    return thumbAsync.when(
      loading: () => _SkeletonBox(size: size, fill: fill),
      error: (_, __) => _icon(context),
      data: (url) {
        if (url == null || url.isEmpty) return _icon(context);
        return _buildImage(context, url);
      },
    );
  }

  Widget _buildImage(BuildContext context, String url) {
    final img = CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => _SkeletonBox(size: size, fill: fill),
      errorWidget: (_, __, ___) => _icon(context),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(rounded ? 6 : 0),
      child: fill
          ? SizedBox.expand(child: img)
          : SizedBox(width: size, height: size, child: img),
    );
  }

  Widget _icon(BuildContext context) =>
      Icon(fileIcon(file), size: size, color: fileIconColor(context, file));
}

/// 灰色骨架屏：用于缩略图加载中的占位动画。
class _SkeletonBox extends StatefulWidget {
  final double size;
  final bool fill;

  const _SkeletonBox({this.size = 56, this.fill = false});

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final base = colors.surfaceMuted;
    final highlight = colors.border;
    final box = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final dx = t * 2 - 1; // -1 -> 1
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: LinearGradient(
              begin: Alignment(dx - 1.5, -1),
              end: Alignment(dx + 1.5, 1),
              colors: [base, highlight, base],
              stops: const [0.3, 0.5, 0.7],
            ),
          ),
        );
      },
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: widget.fill
          ? SizedBox.expand(child: box)
          : SizedBox(width: widget.size, height: widget.size, child: box),
    );
  }
}
