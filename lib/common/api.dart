// ignore_for_file: library_prefixes

import 'dart:async';
import 'dart:convert';

import 'package:cloudreve_view/controller.dart';
import 'package:cloudreve_view/entity/user.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart' as GetX;

abstract class ApiConfig {
  static String env = "dev";
  static String protocol = "https";
  static String baseUrl = "${protocol}:";
  static String userAvatarBaseUrl = "${baseUrl}user/avatar/";
  static String fileThumbBaseUrl = "${baseUrl}file/thumb/";
  static String filePreveiewBaseUrl = "${baseUrl}file/preview/";
  static var apis = {
    "login": "user/session",
    "directory": "directory",
  };
}

class Api {
  static final Dio _dio = Dio();
  static final Controller controller = GetX.Get.find<Controller>();

  Api() {
    _dio
      ..options.baseUrl = ApiConfig.baseUrl
      ..options.connectTimeout = const Duration(seconds: 5)
      ..options.receiveTimeout = const Duration(seconds: 3)
      ..options.headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Cookie': controller.session
      };
    _dio.interceptors.add(InterceptorsWrapper(
      onResponse: (Response response, ResponseInterceptorHandler handler) {
        if (response.data != "") {
          if (response.data['code'] == 401) {
            controller.logout();
          }
        }
        return handler.next(response); // 继续处理响应
      },
    ));
  }

  Future<Response> get(String path,
      {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      if (ApiConfig.env == "dev") {
        print(
            "接口${path}:\n${jsonEncode(response.data)}\n请求头${response.headers}");
      }
      return response;
    } on DioException catch (e) {
      // 处理错误
      throw Exception('Failed to load data: $e');
    }
  }

  Future<Response> post(String path, {Map<String, dynamic>? data}) async {
    try {
      final response = await _dio.post(path, data: data);
      if (ApiConfig.env == "dev") {
        print(
            "接口${path}:\n${jsonEncode(response.data)}\n请求头${response.headers}");
      }
      return response;
    } on DioException catch (e) {
      // 处理错误
      throw Exception('Failed to post data: $e');
    }
  }

  /**
   * 登录
   */
  Future<Response> login({required String email, required String password}) {
    Completer<Response> completer = Completer();
    var response = completer.future;
    User user;
    post(ApiConfig.apis["login"]!,
            data: {"UserName": email, "captchaCode": "", "Password": password})
        .then((resp) => {
              if (resp.data["code"] == 0)
                {
                  user = User.fromMap(resp.data['data']),
                  controller.setUser(user),
                  resp.headers.forEach((name, values) {
                    if (name == "set-cookie") {
                      GetX.Get.find<Controller>().setSession(values[0]);
                      completer.complete(resp);
                    }
                  })
                }
              else
                {completer.complete(resp)}
            });
    return response;
  }

  /**
   * 文件列表
   */
  Future<Response> directory({String? path = ""}) {
    return get(Uri.encodeComponent(ApiConfig.apis["directory"]! + path!));
  }

  /**
   * 获取302后的真实文件地址
   */
  Future<String> getPreviewFileUrl(String oUrl) async {
    try {
      var response = await _dio.head(oUrl);
      return response.realUri.toString();
    } catch (e) {
      // 捕获并处理异常
      print(e);
      return "";
    }
  }
}
