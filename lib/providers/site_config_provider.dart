import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../models/site_config.dart';
import 'api_provider.dart';
import 'settings_provider.dart';

/// 当前站点的基础配置（标题 + 主题色）。
final siteConfigProvider = FutureProvider<SiteConfig>((ref) async {
  final site = ref.watch(currentSiteProvider);
  if (site == null) {
    throw const ApiException(-1, '未配置站点');
  }
  final api = ref.watch(apiProvider);
  return api.getSiteConfig();
});

/// 当前站点登录页配置（验证码开关等）。
final loginConfigProvider = FutureProvider<LoginConfig>((ref) async {
  final site = ref.watch(currentSiteProvider);
  if (site == null) {
    throw const ApiException(-1, '未配置站点');
  }
  final api = ref.watch(apiProvider);
  return api.getLoginConfig();
});
