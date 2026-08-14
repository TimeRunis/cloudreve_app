import 'package:dio/dio.dart';

/// Cloudreve API 统一异常。
class ApiException implements Exception {
  final int code;
  final String message;
  final int? statusCode;

  const ApiException(this.code, this.message, {this.statusCode});

  /// 2FA 需要二次验证时返回的业务码。
  static const int twoFactorRequired = 203;

  bool get isTwoFactor => code == twoFactorRequired;

  @override
  String toString() => message.isNotEmpty ? message : 'Error ($code)';
}

ApiException toApiException(Object e) {
  if (e is ApiException) return e;
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['code'] != null) {
      final code = data['code'];
      return ApiException(
        code is int ? code : -1,
        data['msg']?.toString() ?? '',
        statusCode: e.response?.statusCode,
      );
    }
    if (data is Map && data['message'] != null) {
      return ApiException(
        e.response?.statusCode ?? -1,
        data['message']?.toString() ?? '',
        statusCode: e.response?.statusCode,
      );
    }
    return ApiException(
      e.response?.statusCode ?? -1,
      _friendlyMessage(e),
      statusCode: e.response?.statusCode,
    );
  }
  return ApiException(-1, e.toString());
}

String _friendlyMessage(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return '请求超时';
    case DioExceptionType.connectionError:
      return '网络连接失败';
    case DioExceptionType.badResponse:
      return '服务器错误 (${e.response?.statusCode})';
    default:
      final err = e.error?.toString() ?? '';
      if (err.contains('CERTIFICATE') || err.contains('Handshake')) {
        return '证书校验失败，请到「站点」设置里开启该站点的「跳过 HTTPS 证书校验」';
      }
      return e.message ?? '请求失败';
  }
}
