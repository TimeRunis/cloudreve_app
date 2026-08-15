import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/download/download_manager.dart';
import 'api_provider.dart';
import 'settings_provider.dart';
import 'storage_provider.dart';

/// 下载管理器状态包装：每次任务变化都生成新对象，确保 Riverpod 一定通知 UI。
class DownloadManagerState {
  final DownloadManager manager;

  const DownloadManagerState(this.manager);
}

/// 全局下载管理器（应用生命周期内单例，切页面 / 退到后台仍持续下载）。
final downloadManagerProvider =
    NotifierProvider<DownloadManagerNotifier, DownloadManagerState>(
        DownloadManagerNotifier.new);

class DownloadManagerNotifier extends Notifier<DownloadManagerState> {
  late DownloadManager _manager;

  @override
  DownloadManagerState build() {
    final manager = DownloadManager(
      storage: ref.watch(storageProvider),
      dio: ref.watch(dioProvider),
      settingsOf: () {
        final settings = ref.read(settingsProvider);
        return DownloadSettings(
          multiThread: settings.multiThreadDownload,
          threadCount: settings.downloadThreadCount,
        );
      },
      // 失败重试前按 URI 重新获取直链（签名直链可能过期）。
      urlFetcher: (uri) async {
        final api = ref.read(apiProvider);
        final url = await api.getFileSourceUrl(uri);
        if (url == null || url.isEmpty) return null;
        if (url.startsWith('http://') || url.startsWith('https://')) {
          return url;
        }
        final base =
            api.site?.normalizedBaseUrl.replaceAll(RegExp(r'/$'), '') ?? '';
        return url.startsWith('/') ? '$base$url' : '$base/$url';
      },
    );
    _manager = manager;
    manager.init();
    // 把 ChangeNotifier 的更新桥接到 Riverpod：每次创建新包装对象，保证通知。
    manager.addListener(_onManagerChanged);
    ref.onDispose(() {
      manager.removeListener(_onManagerChanged);
      manager.dispose();
    });
    return DownloadManagerState(manager);
  }

  void _onManagerChanged() {
    state = DownloadManagerState(_manager);
  }
}
