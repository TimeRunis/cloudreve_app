import 'package:wakelock_plus/wakelock_plus.dart';

/// 全局 wakelock 持有者集合。
///
/// 下载和上传是不同的 Manager，各自不知道对方是否还在运行。
/// 这里按持有者名称去重管理：同一位持有者重复 acquire 不会重复计数，
/// 只有所有持有者都 release 时才真正关闭 CPU 唤醒锁。
class AppWakeLock {
  static final Set<String> _holders = {};

  /// 持有一份 wakelock；首次有持有者时才真正 enable。
  static void acquire(String holder) {
    final wasEmpty = _holders.isEmpty;
    _holders.add(holder);
    if (wasEmpty) {
      WakelockPlus.enable();
    }
  }

  /// 释放一份 wakelock；所有持有者都释放后才真正 disable。
  static void release(String holder) {
    final removed = _holders.remove(holder);
    if (removed && _holders.isEmpty) {
      WakelockPlus.disable();
    }
  }

  /// 仅供调试/清理时重置持有者。
  static void reset() => _holders.clear();
}