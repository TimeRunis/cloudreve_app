import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/cloudreve_api.dart';
import 'auth_provider.dart';
import 'settings_provider.dart';

/// 全局唯一的 Dio 实例（整个应用只有一个）。
final dioProvider = Provider<Dio>((ref) => createDio());

/// 当前站点 + 令牌对应的 API 客户端（复用全局 Dio，仅做运行时配置）。
final apiProvider = Provider<CloudreveApi>((ref) {
  final dio = ref.watch(dioProvider);
  final site = ref.watch(currentSiteProvider);
  final token = ref.watch(authProvider).token;
  return CloudreveApi(
    dio: dio,
    site: site,
    token: token,
    // access token 超过 25 分钟时，每次请求前自动用 refresh_token 换取新令牌。
    onRefreshToken: (refreshToken) async {
      final api = CloudreveApi(dio: dio, site: site, token: token);
      final newPair = await api.refreshToken(refreshToken);
      final currentSite = ref.read(currentSiteProvider);
      if (currentSite != null) {
        return await ref
            .read(authProvider.notifier)
            .updateToken(currentSite, newPair);
      }
      return newPair;
    },
  );
});
