import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/site.dart';
import 'sites_provider.dart';
import 'storage_provider.dart';

/// 应用设置：主题模式 + 当前站点 id + 下载设置。
class AppSettings {
  final String themeMode; // system / light / dark
  final String? currentSiteId;

  /// 是否开启多线程下载（默认关闭）。
  final bool multiThreadDownload;

  /// 多线程下载线程数（2-16）。
  final int downloadThreadCount;

  const AppSettings({
    this.themeMode = 'system',
    this.currentSiteId,
    this.multiThreadDownload = false,
    this.downloadThreadCount = 4,
  });

  AppSettings copyWith({
    String? themeMode,
    String? currentSiteId,
    bool? multiThreadDownload,
    int? downloadThreadCount,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        currentSiteId: currentSiteId ?? this.currentSiteId,
        multiThreadDownload:
            multiThreadDownload ?? this.multiThreadDownload,
        downloadThreadCount: downloadThreadCount ?? this.downloadThreadCount,
      );
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final storage = ref.read(storageProvider);
    return AppSettings(
      themeMode: storage.getThemeMode(),
      currentSiteId: storage.getCurrentSiteId(),
      multiThreadDownload: storage.getMultiThreadDownload(),
      downloadThreadCount: storage.getDownloadThreadCount(),
    );
  }

  Future<void> setThemeMode(String mode) async {
    state = state.copyWith(themeMode: mode);
    await ref.read(storageProvider).setThemeMode(mode);
  }

  Future<void> setCurrentSite(String id) async {
    state = state.copyWith(currentSiteId: id);
    await ref.read(storageProvider).setCurrentSiteId(id);
  }

  Future<void> setMultiThreadDownload(bool enabled) async {
    state = state.copyWith(multiThreadDownload: enabled);
    await ref.read(storageProvider).setMultiThreadDownload(enabled);
  }

  Future<void> setDownloadThreadCount(int count) async {
    final clamped = count.clamp(2, 16).toInt();
    state = state.copyWith(downloadThreadCount: clamped);
    await ref.read(storageProvider).setDownloadThreadCount(clamped);
  }
}

/// 当前站点：优先用已选 id，否则回退到第一个站点。
final currentSiteProvider = Provider<Site?>((ref) {
  final sites = ref.watch(sitesProvider);
  if (sites.isEmpty) return null;
  final currentId = ref.watch(settingsProvider).currentSiteId;
  if (currentId != null) {
    for (final s in sites) {
      if (s.id == currentId) return s;
    }
  }
  return sites.first;
});
