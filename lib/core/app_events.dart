import 'package:flutter/services.dart';

/// 原生 → Flutter 应用级事件桥（例如通知栏点击）。
///
/// 只负责收发事件字符串，不依赖任何页面；页面自行监听感兴趣的事件。
/// 后续如需「通知点击打开上传页」，新增事件名并在对应页面监听即可。
class AppEventBus {
  static const MethodChannel _channel =
      MethodChannel('cloudreve/app_events');

  static final List<void Function(String)> _listeners = [];
  static bool _pendingOpenDownloads = false;

  /// 在 runApp 之前调用：注册原生事件回调，并领取冷启动时由通知点击
  /// 带入的待处理事件。
  static Future<void> init() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'open_downloads') {
        _emit('open_downloads');
      }
      return null;
    });
    try {
      final pending =
          await _channel.invokeMethod<String?>('consumePendingEvent');
      if (pending == 'open_downloads') {
        _pendingOpenDownloads = true;
      }
    } catch (_) {
      // 非 Android 平台无此通道。
    }
  }

  static void addListener(void Function(String event) listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  static void removeListener(void Function(String event) listener) {
    _listeners.remove(listener);
  }

  /// 冷启动时由根页面领取「通知点击打开下载页」事件。
  static bool consumePendingOpenDownloads() {
    final pending = _pendingOpenDownloads;
    _pendingOpenDownloads = false;
    return pending;
  }

  static void _emit(String event) {
    for (final listener in List<void Function(String)>.of(_listeners)) {
      listener(event);
    }
  }
}
