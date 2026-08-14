import 'package:dio/dio.dart';

import '../../models/file_item.dart';
import '../../models/site.dart';
import '../../models/site_config.dart';
import '../../models/user.dart';
import 'api_exception.dart';
import 'tls_override.dart';

/// 验证码结果。
class CaptchaResult {
  final String image; // base64 data uri
  final String ticket;

  const CaptchaResult({required this.image, required this.ticket});

  factory CaptchaResult.fromJson(Map<String, dynamic> json) => CaptchaResult(
        image: json['image'] as String? ?? '',
        ticket: json['ticket'] as String? ?? '',
      );
}

/// 普通路径 → Cloudreve URI（cloudreve://my/...）。
String pathToUri(String path) {
  var p = path;
  if (p.startsWith('cloudreve://')) return p;
  if (p.isEmpty) p = '/';
  if (!p.startsWith('/')) p = '/$p';
  return 'cloudreve://my$p';
}

/// 创建全局唯一的 Dio 实例（基础配置，不含站点相关项）。
Dio createDio() => Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));

/// Cloudreve v4 API 客户端（复用全局 Dio 单例，只负责站点相关的运行时配置）。
class CloudreveApi {
  final Dio dio;
  final Site? site;
  final TokenPair? token;

  CloudreveApi({required this.dio, this.site, this.token}) {
    dio.options.baseUrl = site == null ? '' : '${site!.apiBase}/';
    if (token != null) {
      dio.options.headers['Authorization'] = 'Bearer ${token!.accessToken}';
    } else {
      dio.options.headers.remove('Authorization');
    }
    // 按当前站点是否开启「跳过证书校验」更新全局开关。
    TlsTrustManager.skipVerify = site?.skipTlsVerify == true;
    print('[CloudreveApi] 初始化 site=${site?.name} '
        'skipTlsVerify=${site?.skipTlsVerify} '
        '-> TlsTrustManager.skipVerify=${TlsTrustManager.skipVerify}');
  }

  String _url(String path) =>
      path.startsWith('/') ? path.substring(1) : path;

  void _logError(String path, Object e) {
    print('[CloudreveApi] $path 请求失败: $e');
    if (e is DioException) {
      print('[CloudreveApi] type=${e.type} message=${e.message} '
          'status=${e.response?.statusCode} '
          'skipTlsVerify=${TlsTrustManager.skipVerify}');
    }
  }

  Future<dynamic> _get(String path,
      {Map<String, dynamic>? queryParameters}) async {
    try {
      final resp = await dio.get<dynamic>(_url(path),
          queryParameters: queryParameters);
      return _unwrap(resp);
    } catch (e) {
      _logError(path, e);
      throw toApiException(e);
    }
  }

  Future<dynamic> _post(String path, {Object? data}) async {
    try {
      final resp = await dio.post<dynamic>(_url(path), data: data);
      return _unwrap(resp);
    } catch (e) {
      _logError(path, e);
      throw toApiException(e);
    }
  }

  /// 解包统一响应壳 {code, data, msg}。
  dynamic _unwrap(Response<dynamic> resp) {
    final data = resp.data;
    if (data is Map && data.containsKey('code')) {
      final code = data['code'];
      final isOk = code == 0 || code == '0';
      if (!isOk) {
        final c = code is int ? code : -1;
        throw ApiException(c, data['msg']?.toString() ?? '',
            statusCode: resp.statusCode);
      }
      return data['data'];
    }
    return data;
  }

  // ---------- 站点配置 ----------
  Future<SiteConfig> getSiteConfig() async {
    final data = await _get('site/config/basic');
    return SiteConfig.fromJson(data as Map<String, dynamic>);
  }

  Future<LoginConfig> getLoginConfig() async {
    final data = await _get('site/config/login');
    return LoginConfig.fromJson(data as Map<String, dynamic>? ?? {});
  }

  // ---------- 验证码 ----------
  Future<CaptchaResult> getCaptcha() async {
    final data = await _get('site/captcha');
    return CaptchaResult.fromJson(data as Map<String, dynamic>);
  }

  // ---------- 认证 ----------
  Future<LoginResult> login({
    required String email,
    required String password,
    String? captcha,
    String? ticket,
  }) async {
    final data = await _post('session/token', data: {
      'email': email,
      'password': password,
      if (captcha != null) 'captcha': captcha,
      if (ticket != null) 'ticket': ticket,
    });
    return LoginResult.fromJson(data as Map<String, dynamic>);
  }

  Future<TokenPair> refreshToken(String refreshToken) async {
    final data = await _post('session/token/refresh',
        data: {'refresh_token': refreshToken});
    return TokenPair.fromJson(data as Map<String, dynamic>);
  }

  Future<User> getMe() async {
    final data = await _get('user/me');
    return User.fromJson(data as Map<String, dynamic>);
  }

  Future<Capacity> getCapacity() async {
    final data = await _get('user/capacity');
    return Capacity.fromJson(data as Map<String, dynamic>);
  }

  // ---------- 文件 ----------
  Future<DirectoryListing> listFiles(
    String path, {
    int? page,
    int? pageSize,
    String? orderBy,
    String? orderDirection,
  }) async {
    final data = await _get('file', queryParameters: {
      'uri': pathToUri(path),
      if (page != null) 'page': page,
      if (pageSize != null) 'page_size': pageSize,
      if (orderBy != null) 'order_by': orderBy,
      if (orderDirection != null) 'order_direction': orderDirection,
    });
    return DirectoryListing.fromJson(data as Map<String, dynamic>);
  }

  /// 获取缩略图直链；返回 data.url，失败返回 null。
  Future<String?> getThumbnailUrl(String uri, {int? width, int? height}) async {
    final data = await _get('file/thumb', queryParameters: {
      'uri': uri,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
    });
    if (data is Map && data['url'] != null) {
      return data['url'] as String;
    }
    if (data is String) return data;
    return null;
  }

  /// 创建源文件下载直链（原图 / 下载用）；返回 data.urls[0].url，失败返回 null。
  Future<String?> getFileSourceUrl(String uri) async {
    final data = await _post('file/url', data: {
      'uris': [uri],
    });
    if (data is Map) {
      final urls = data['urls'];
      if (urls is List && urls.isNotEmpty && urls.first is Map) {
        final url = (urls.first as Map)['url'];
        if (url is String && url.isNotEmpty) return url;
      }
    }
    if (data is String) return data;
    return null;
  }
}
