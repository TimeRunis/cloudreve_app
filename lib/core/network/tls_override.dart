import 'dart:io';

/// 全局证书信任开关（按「当前站点」是否跳过校验动态变化）。
class TlsTrustManager {
  static bool skipVerify = false;
}

/// 安装全局 HttpClient 覆盖：所有请求在握手时按 [TlsTrustManager.skipVerify]
/// 决定是否跳过证书校验。这样即使 HttpClient 被 Dio 缓存，开关也能即时生效。
void installTlsTrustOverride() {
  HttpOverrides.global = _TlsTrustOverrides();
}

class _TlsTrustOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback =
        (cert, host, port) => TlsTrustManager.skipVerify;
    return client;
  }
}
