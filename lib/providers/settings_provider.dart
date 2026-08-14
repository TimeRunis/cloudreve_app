import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/site.dart';
import 'sites_provider.dart';
import 'storage_provider.dart';

/// 应用设置：主题模式 + 当前站点 id。
class AppSettings {
  final String themeMode; // system / light / dark
  final String? currentSiteId;

  const AppSettings({this.themeMode = 'system', this.currentSiteId});

  AppSettings copyWith({String? themeMode, String? currentSiteId}) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        currentSiteId: currentSiteId ?? this.currentSiteId,
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
