import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/site.dart';
import 'storage_provider.dart';

/// 站点列表（本地持久化）。
final sitesProvider = NotifierProvider<SitesNotifier, List<Site>>(
  SitesNotifier.new,
);

class SitesNotifier extends Notifier<List<Site>> {
  @override
  List<Site> build() => ref.read(storageProvider).getSites();

  Future<void> _persist() =>
      ref.read(storageProvider).saveSites(state);

  Future<void> addSite(Site site) async {
    final others = state.where((e) => e.id != site.id).toList();
    state = [...others, site];
    await _persist();
  }

  Future<void> updateSite(Site site) => addSite(site);

  Future<void> removeSite(String id) async {
    state = state.where((e) => e.id != id).toList();
    await _persist();
    await ref.read(storageProvider).clearToken(id);
  }
}
