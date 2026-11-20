import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/site.dart';
import '../../models/user.dart';
import '../../providers/settings_provider.dart';

/// 用户头像地址。
///
/// `avatar` 是服务端返回的头像来源（`file` 上传头像 / `gravatar`），
/// 有值时统一走 `/user/avatar/{user_id}` 取图；为空表示没有设置头像。
String? userAvatarUrl(Site? site, User? user) {
  final avatar = user?.avatar ?? '';
  if (avatar.isEmpty || site == null || user == null) return null;
  return '${site.apiBase}/user/avatar/${Uri.encodeComponent(user.id)}';
}

/// 右上角用户头像：有头像就显示头像，没有则回退到昵称首字母。
class UserAvatar extends ConsumerWidget {
  final User? user;
  final VoidCallback onTap;

  const UserAvatar({super.key, required this.user, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = user?.nickname ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final url = userAvatarUrl(ref.watch(currentSiteProvider), user);
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: Theme.of(context).colorScheme.primary,
        // 加载中先显示首字母，图片加载失败也保持首字母，不会出现空白头像。
        foregroundImage: url == null ? null : CachedNetworkImageProvider(url),
        onForegroundImageError: url == null ? null : (_, __) {},
        child: Text(
          initial,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}
