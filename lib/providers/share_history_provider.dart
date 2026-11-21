import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/share_history.dart';
import 'storage_provider.dart';

/// 本地分享打开历史（最新在前，最多保留 100 条）。
final shareHistoryProvider =
    NotifierProvider<ShareHistoryNotifier, List<ShareHistoryEntry>>(
  ShareHistoryNotifier.new,
);

class ShareHistoryNotifier extends Notifier<List<ShareHistoryEntry>> {
  static const int maxEntries = 100;

  @override
  List<ShareHistoryEntry> build() {
    try {
      return ref.read(storageProvider).getShareHistory();
    } catch (_) {
      return const [];
    }
  }

  /// 记录一次打开；同一站点下的同一个分享会移到最前。
  Future<void> add(ShareHistoryEntry entry) async {
    final next = [...state]..removeWhere((e) => e.id == entry.id);
    next.insert(0, entry);
    if (next.length > maxEntries) {
      next.removeRange(maxEntries, next.length);
    }
    state = next;
    await _persist(next);
  }

  /// 删除指定记录。
  Future<void> remove(Set<String> ids) async {
    final next = state.where((e) => !ids.contains(e.id)).toList();
    state = next;
    await _persist(next);
  }

  /// 清空全部记录。
  Future<void> clear() async {
    state = const [];
    await _persist(const []);
  }

  Future<void> _persist(List<ShareHistoryEntry> entries) async {
    try {
      await ref.read(storageProvider).saveShareHistory(entries);
    } catch (_) {
      // 本地存储失败时保留内存中的历史，不影响分享页打开。
    }
  }
}
