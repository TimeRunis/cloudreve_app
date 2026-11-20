import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../models/file_item.dart';
import '../../providers/settings_provider.dart';
import 'file_icon.dart';

/// 文件 / 文件夹图标，右下角按服务端状态叠加徽标：
///
/// - **收藏的分享链接**（`metadata.sys:shared_redirect`）：分享人头像徽标，
///   头像取不到时回退成分享图标；
/// - **已分享出去的条目**（`shared == true`）：分享图标徽标。
///
/// 两种状态都来自 `GET /file` 的返回字段，列表 / 网格 / 侧边栏共用这一套。
class FileItemIcon extends StatelessWidget {
  final FileItem file;

  /// 基础图标尺寸，徽标按比例缩放。
  final double size;

  /// 图标颜色，默认按文件类型取色。
  final Color? color;

  const FileItemIcon({
    super.key,
    required this.file,
    this.size = 20,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      fileIcon(file),
      size: size,
      color: color ?? fileIconColor(context, file),
    );
    final badgeSize = size * 0.62;

    final Widget? badge;
    if (file.isShareShortcut) {
      badge = ShareOwnerAvatarBadge(owner: file.sharedOwner, size: badgeSize);
    } else if (file.shared) {
      badge = ShareGlyphBadge(size: badgeSize);
    } else {
      badge = null;
    }
    if (badge == null) return icon;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          right: -size * 0.24,
          bottom: -size * 0.22,
          child: badge,
        ),
      ],
    );
  }
}

/// 分享状态小徽标：白底圆形 + 分享图标。
class ShareGlyphBadge extends StatelessWidget {
  final double size;

  const ShareGlyphBadge({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surface,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Icon(
        Icons.share,
        size: size * 0.62,
        color: colors.textSecondary,
      ),
    );
  }
}

/// 分享人头像徽标：圆形头像，取不到时退化为分享图标。
class ShareOwnerAvatarBadge extends ConsumerWidget {
  /// 分享人用户 ID（`sys:shared_owner`，对应 `/user/avatar/{id}`）。
  final String? owner;

  final double size;

  const ShareOwnerAvatarBadge({
    super.key,
    required this.owner,
    required this.size,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final ownerId = owner;
    final site = ref.watch(currentSiteProvider);
    if (ownerId == null || site == null) {
      return ShareGlyphBadge(size: size);
    }
    final url = '${site.apiBase}/user/avatar/'
        '${Uri.encodeComponent(ownerId)}';
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 120),
        placeholder: (_, __) => Icon(
          Icons.person,
          size: size * 0.62,
          color: colors.textMuted,
        ),
        errorWidget: (_, __, ___) => Icon(
          Icons.share,
          size: size * 0.55,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}
