import 'package:flutter/services.dart';

/// Android 通知栏下载进度桥接。
///
/// 原生端在 MainActivity 中处理；非 Android 平台或系统未授予通知权限时
/// 调用会静默失败，不影响下载本身。
class DownloadNotifications {
  static const MethodChannel _channel =
      MethodChannel('cloudreve/download_notifications');

  /// 显示 / 更新进度通知。
  static Future<void> show({
    required int id,
    required String title,
    required String text,
    required int percent,
  }) async {
    try {
      await _channel.invokeMethod<void>('show', {
        'id': id,
        'title': title,
        'text': text,
        'percent': percent.clamp(0, 100),
      });
    } catch (_) {
      // 通知失败不影响下载。
    }
  }

  /// 结束进度（完成 / 失败 / 暂停时调用，通知变为普通通知）。
  static Future<void> finish({
    required int id,
    required String title,
    required String text,
  }) async {
    try {
      await _channel.invokeMethod<void>('finish', {
        'id': id,
        'title': title,
        'text': text,
      });
    } catch (_) {}
  }

  /// 移除通知。
  static Future<void> cancel(int id) async {
    try {
      await _channel.invokeMethod<void>('cancel', {'id': id});
    } catch (_) {}
  }

  /// 启动下载守护前台服务（锁屏 / 后台保持进程与网络运行）。
  static Future<void> startService({
    required String title,
    required String text,
    required int percent,
  }) async {
    try {
      await _channel.invokeMethod<void>('startService', {
        'title': title,
        'text': text,
        'percent': percent.clamp(0, 100),
      });
    } catch (_) {}
  }

  /// 更新前台服务通知（总进度）。
  static Future<void> updateService({
    required String title,
    required String text,
    required int percent,
  }) async {
    try {
      await _channel.invokeMethod<void>('updateService', {
        'title': title,
        'text': text,
        'percent': percent.clamp(0, 100),
      });
    } catch (_) {}
  }

  /// 停止下载守护前台服务。
  static Future<void> stopService() async {
    try {
      await _channel.invokeMethod<void>('stopService');
    } catch (_) {}
  }
}
