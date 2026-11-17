import 'package:dio/dio.dart';

import '../log/app_log.dart';

/// dio 自带 [LogInterceptor] 的配置版：所有网络日志统一写入 [AppLogger]。
///
/// - 关闭请求头/响应头：避免把 `Authorization` 等凭据写进日志；
/// - 关闭请求体：避免上传分片的二进制内容撑爆日志；
/// - 保留响应体：400 这类错误的原因通常只出现在 body 里。
LogInterceptor createApiLogInterceptor() => LogInterceptor(
      requestHeader: false,
      responseHeader: false,
      requestBody: false,
      responseBody: true,
      error: true,
      logPrint: (object) => AppLogger.log.d(object),
    );
