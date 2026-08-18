import 'package:dio/dio.dart';

import '../../models/file_item.dart';
import '../../models/share.dart';
import '../../models/site.dart';
import '../../models/site_config.dart';
import '../../models/upload_task.dart';
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

/// 分享根目录 URI：`cloudreve://{shareId}[:password]@share`。
String shareRootUri(String shareId, {String? password}) {
  final user = password == null || password.isEmpty
      ? shareId
      : '$shareId:$password';
  return 'cloudreve://$user@share';
}

/// 分享内文件/文件夹 URI，[path] 为分享根目录下的相对路径（斜杠分隔）。
String shareUri(String shareId, {String? password, String path = ''}) {
  final root = shareRootUri(shareId, password: password);
  if (path.isEmpty || path == '/') return root;
  final clean = path.startsWith('/') ? path.substring(1) : path;
  final encoded = clean
      .split('/')
      .where((s) => s.isNotEmpty)
      .map(Uri.encodeComponent)
      .join('/');
  return '$root/$encoded';
}

/// 解析出的分享链接。
class ParsedShareLink {
  final String shareId;
  final String? password;

  const ParsedShareLink({required this.shareId, this.password});
}

/// 从剪贴板文本中解析某个站点的分享短链（`/s/{id}[/{password}]`）。
///
/// 也兼容 `cloudreve://{id}[:password]@share` 形式的 URI。
ParsedShareLink? parseShareLinkFromText(String text, String siteBaseUrl) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;

  // 先尝试 cloudreve:// 分享 URI。
  final uriMatch = RegExp(
    r'cloudreve://([A-Za-z0-9_-]+)(?::([A-Za-z0-9_-]+))?@share',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (uriMatch != null) {
    return ParsedShareLink(
      shareId: uriMatch.group(1)!,
      password: uriMatch.group(2),
    );
  }

  // 从整段文本中提取第一个完整 URL。
  final urlMatch = RegExp(r'https?://[^\s<>"]+', caseSensitive: false)
      .firstMatch(trimmed);
  final raw = urlMatch?.group(0) ?? trimmed;
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;

  final baseUri = Uri.tryParse(siteBaseUrl);
  if (baseUri == null) return null;
  final sameHost = uri.host == baseUri.host;
  final samePort = uri.hasPort
      ? uri.port == (baseUri.hasPort ? baseUri.port : (baseUri.scheme == 'https' ? 443 : 80))
      : !baseUri.hasPort;
  if (!sameHost || !samePort) return null;

  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length < 2 || segments[0] != 's') return null;
  return ParsedShareLink(
    shareId: segments[1],
    password: segments.length >= 3 ? segments[2] : null,
  );
}

/// 登录令牌自动刷新回调：传入 refresh_token，返回新的 TokenPair。
typedef TokenRefresher = Future<TokenPair> Function(String refreshToken);

/// Cloudreve v4 API 客户端（复用全局 Dio 单例，只负责站点相关的运行时配置）。
class CloudreveApi {
  /// access token 有效期按 25 分钟提前刷新。
  static const int accessTokenLifetimeMs = 25 * 60 * 1000;

  final Dio dio;
  final Site? site;
  final TokenPair? token;
  final TokenRefresher? onRefreshToken;

  TokenPair? _currentToken;
  Future<TokenPair?>? _refreshing;

  CloudreveApi({
    required this.dio,
    this.site,
    this.token,
    this.onRefreshToken,
  }) {
    _currentToken = token;
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

  /// 请求前校验 access token：超过 25 分钟则主动刷新。
  Future<bool> _ensureFreshToken() async {
    final current = _currentToken;
    if (onRefreshToken == null ||
        current == null ||
        current.refreshToken.isEmpty) {
      return false;
    }
    final issuedAt = current.accessIssuedAt;
    final ageMs = issuedAt == null
        ? accessTokenLifetimeMs + 1
        : DateTime.now().difference(issuedAt).inMilliseconds;
    if (ageMs < accessTokenLifetimeMs) {
      return true;
    }
    return await _tryRefresh();
  }

  /// 401 时用 refresh_token 刷新令牌；并发请求共享同一次刷新。
  Future<bool> _tryRefresh() async {
    final refreshToken = _currentToken?.refreshToken;
    if (onRefreshToken == null ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      return false;
    }
    if (_refreshing != null) {
      final result = await _refreshing;
      return result != null;
    }
    final future = _doRefresh(refreshToken);
    _refreshing = future;
    try {
      final result = await future;
      return result != null;
    } finally {
      _refreshing = null;
    }
  }

  Future<TokenPair?> _doRefresh(String refreshToken) async {
    try {
      final newPair = await onRefreshToken!(refreshToken);
      _currentToken = newPair;
      dio.options.headers['Authorization'] = 'Bearer ${newPair.accessToken}';
      return newPair;
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> _get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool retryOnUnauthorized = true,
  }) async {
    if (retryOnUnauthorized) {
      await _ensureFreshToken();
    }
    try {
      final resp = await dio.get<dynamic>(_url(path),
          queryParameters: queryParameters);
      return _unwrap(resp);
    } on DioException catch (e) {
      if (retryOnUnauthorized &&
          e.response?.statusCode == 401 &&
          await _tryRefresh()) {
        return _get(path,
            queryParameters: queryParameters, retryOnUnauthorized: false);
      }
      _logError(path, e);
      throw toApiException(e);
    } catch (e) {
      _logError(path, e);
      throw toApiException(e);
    }
  }

  Future<dynamic> _post(
    String path, {
    Object? data,
    bool retryOnUnauthorized = true,
  }) async {
    if (retryOnUnauthorized) {
      await _ensureFreshToken();
    }
    try {
      final resp = await dio.post<dynamic>(_url(path), data: data);
      return _unwrap(resp);
    } on DioException catch (e) {
      if (retryOnUnauthorized &&
          e.response?.statusCode == 401 &&
          await _tryRefresh()) {
        return _post(path, data: data, retryOnUnauthorized: false);
      }
      _logError(path, e);
      throw toApiException(e);
    } catch (e) {
      _logError(path, e);
      throw toApiException(e);
    }
  }

  Future<dynamic> _put(
    String path, {
    Object? data,
    bool retryOnUnauthorized = true,
  }) async {
    if (retryOnUnauthorized) {
      await _ensureFreshToken();
    }
    try {
      final resp = await dio.put<dynamic>(_url(path), data: data);
      return _unwrap(resp);
    } on DioException catch (e) {
      if (retryOnUnauthorized &&
          e.response?.statusCode == 401 &&
          await _tryRefresh()) {
        return _put(path, data: data, retryOnUnauthorized: false);
      }
      _logError(path, e);
      throw toApiException(e);
    } catch (e) {
      _logError(path, e);
      throw toApiException(e);
    }
  }

  Future<dynamic> _delete(
    String path, {
    Object? data,
    bool retryOnUnauthorized = true,
  }) async {
    if (retryOnUnauthorized) {
      await _ensureFreshToken();
    }
    try {
      final resp =
          await dio.delete<dynamic>(_url(path), data: data);
      return _unwrap(resp);
    } on DioException catch (e) {
      if (retryOnUnauthorized &&
          e.response?.statusCode == 401 &&
          await _tryRefresh()) {
        return _delete(path, data: data, retryOnUnauthorized: false);
      }
      _logError(path, e);
      throw toApiException(e);
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
        data: {'refresh_token': refreshToken}, retryOnUnauthorized: false);
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

  /// 批量创建源文件下载直链；返回与 [uris] 顺序对应的 url 列表。
  Future<List<String>> getFileSourceUrls(List<String> uris) async {
    if (uris.isEmpty) return const [];
    final data = await _post('file/url', data: {'uris': uris});
    final result = <String>[];
    if (data is Map) {
      final urls = data['urls'];
      if (urls is List) {
        for (final item in urls) {
          if (item is Map && item['url'] is String) {
            final url = item['url'] as String;
            if (url.isNotEmpty) result.add(url);
          } else if (item is String && item.isNotEmpty) {
            result.add(item);
          }
        }
      }
    }
    if (result.isEmpty && data is String && data.isNotEmpty) {
      return [data];
    }
    return result;
  }

  // ---------- 分享 ----------

  /// 获取我的分享列表。
  Future<List<ShareLink>> listMyShares({
    int pageSize = 50,
    String? nextPageToken,
  }) async {
    final data = await _get('share', queryParameters: {
      'page_size': pageSize,
      if (nextPageToken != null && nextPageToken.isNotEmpty)
        'next_page_token': nextPageToken,
    });
    if (data is Map && data['shares'] is List) {
      return (data['shares'] as List<dynamic>)
          .map((e) => ShareLink.fromJson(
              (e as Map).cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }

  /// 创建分享链接，返回分享 URL。
  Future<String> createShare({
    required String uri,
    bool? isPrivate,
    String? password,
    int? expire,
    bool? shareView,
    bool? showReadme,
    Map<String, dynamic>? permissions,
  }) async {
    final data = await _put('share', data: {
      'uri': uri,
      'permissions': permissions ??
          {
            'anonymous': 'AQ==',
            'everyone': 'AQ==',
          },
      if (isPrivate != null) 'is_private': isPrivate,
      if (password != null && password.isNotEmpty) 'password': password,
      if (expire != null && expire > 0) 'expire': expire,
      if (shareView != null) 'share_view': shareView,
      if (showReadme != null) 'show_readme': showReadme,
    });
    if (data is String) return data;
    return '';
  }

  /// 删除分享链接。
  Future<void> deleteShare(String id) async {
    await _delete('share/$id');
  }

  /// 获取分享链接信息（外部分享链接打开时使用）。
  Future<ShareLink> getShareInfo(
    String id, {
    String? password,
    bool countViews = false,
    bool ownerExtended = false,
  }) async {
    final data = await _get(
      'share/info/$id',
      queryParameters: {
        if (password != null && password.isNotEmpty) 'password': password,
        if (countViews) 'count_views': true,
        if (ownerExtended) 'owner_extended': true,
      },
    );
    return ShareLink.fromJson(data as Map<String, dynamic>);
  }

  // ---------- 上传 ----------

  /// 创建上传会话。
  Future<UploadSession> createUploadSession({
    required String uri,
    required int size,
    int? lastModified,
    String? mimeType,
    String? entityType,
  }) async {
    final data = await _put('file/upload', data: {
      'uri': uri,
      'size': size,
      if (lastModified != null) 'last_modified': lastModified,
      if (mimeType != null) 'mime_type': mimeType,
      if (entityType != null) 'entity_type': entityType,
    });
    return UploadSession.fromJson(data as Map<String, dynamic>);
  }

  /// 上传单个分片（适用于本地存储或 relay 模式）。
  Future<void> uploadChunk({
    required String sessionId,
    required int index,
    required List<int> bytes,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    final Options options = Options(
      headers: {
        'Content-Type': 'application/octet-stream',
        'Content-Length': '${bytes.length}',
      },
      sendTimeout: const Duration(minutes: 10),
      receiveTimeout: const Duration(minutes: 5),
    );
    await _ensureFreshToken();
    try {
      final resp = await dio.post<dynamic>(
        'file/upload/$sessionId/$index',
        data: bytes,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );
      _unwrap(resp);
    } on DioException catch (e) {
      if (cancelToken?.isCancelled == true) rethrow;
      if (e.response?.statusCode == 401 && await _tryRefresh()) {
        final resp = await dio.post<dynamic>(
          'file/upload/$sessionId/$index',
          data: bytes,
          options: options,
          cancelToken: cancelToken,
          onSendProgress: onSendProgress,
        );
        _unwrap(resp);
        return;
      }
      _logError('file/upload/$sessionId/$index', e);
      throw toApiException(e);
    } catch (e) {
      _logError('file/upload/$sessionId/$index', e);
      throw toApiException(e);
    }
  }

  /// 删除文件 / 文件夹。
  ///
  /// [unlink]：保留物理文件，仅解除引用（需用户组开启“高级删除选项”）。
  /// [skipSoftDelete]：为 true 时跳过回收站直接彻底删除；
  /// 为 false 时移入回收站（若站点回收站可用）。
  Future<void> deleteFiles({
    required List<String> uris,
    bool unlink = false,
    bool skipSoftDelete = false,
  }) async {
    await _delete('file', data: {
      'uris': uris,
      'unlink': unlink,
      'skip_soft_delete': skipSoftDelete,
    });
  }

  /// 从回收站恢复到原位置。
  Future<void> restoreFiles({required List<String> uris}) async {
    await _post('file/restore', data: {'uris': uris});
  }

  /// 删除上传会话（取消或失败清理时使用）。
  Future<void> deleteUploadSession({
    required String id,
    required String uri,
  }) async {
    await _delete('file/upload', data: {'id': id, 'uri': uri});
  }

  /// 通知 Cloudreve OneDrive 文件已完成上传。
  Future<void> completeOneDriveUpload({
    required String sessionId,
    required String key,
  }) async {
    await _post(
      'callback/onedrive/$sessionId/$key',
      retryOnUnauthorized: false,
    );
  }
}
