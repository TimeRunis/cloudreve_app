import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/file_item.dart';
import '../providers/directory_provider.dart';
import 'file_icon.dart';

/// 文件缩略图：图片/视频显示缩略图，其余显示图标。
///
/// [fill] 为 true 时，缩略图铺满父级可用空间（用于网格卡片顶部区域）。
class FileThumbnail extends ConsumerWidget {
  final FileItem file;
  final double size;
  final bool rounded;
  final bool fill;

  const FileThumbnail({
    super.key,
    required this.file,
    this.size = 56,
    this.rounded = true,
    this.fill = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (file.isFolder || !hasThumbnail(file)) {
      return _icon(context);
    }
    final thumbAsync = ref.watch(thumbnailUrlProvider(file.path));
    return thumbAsync.when(
      loading: () => const _Spinner(),
      error: (_, __) => _icon(context),
      data: (url) {
        if (url == null || url.isEmpty) return _icon(context);
        final img = CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, __) => const _Spinner(),
          errorWidget: (_, __, ___) => _icon(context),
        );
        return ClipRRect(
          borderRadius: BorderRadius.circular(rounded ? 6 : 0),
          child: fill
              ? SizedBox.expand(child: img)
              : SizedBox(width: size, height: size, child: img),
        );
      },
    );
  }

  Widget _icon(BuildContext context) =>
      Icon(fileIcon(file), size: size, color: fileIconColor(context, file));
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
