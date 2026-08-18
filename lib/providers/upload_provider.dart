import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/upload/upload_manager.dart';
import '../core/upload/upload_strategy.dart';
import 'api_provider.dart';
import 'storage_provider.dart';

/// 上传管理器状态包装：每次任务变化都生成新对象，确保 Riverpod 一定通知 UI。
class UploadManagerState {
  final UploadManager manager;

  const UploadManagerState(this.manager);
}

/// 全局上传管理器（应用生命周期内单例，后台/切页仍持续上传）。
///
/// 后续新增存储策略时，在 [UploadManager] 的 `strategies` 参数中追加
/// 对应的 [UploadStrategy] 实现即可，无需改动调度/持久化逻辑。
final uploadManagerProvider =
    NotifierProvider<UploadManagerNotifier, UploadManagerState>(
        UploadManagerNotifier.new);

class UploadManagerNotifier extends Notifier<UploadManagerState> {
  late UploadManager _manager;

  @override
  UploadManagerState build() {
    final manager = UploadManager(
      storage: ref.watch(storageProvider),
      apiOf: () => ref.read(apiProvider),
    );
    _manager = manager;
    manager.init();
    manager.addListener(_onManagerChanged);
    ref.onDispose(() {
      manager.removeListener(_onManagerChanged);
      manager.dispose();
    });
    return UploadManagerState(manager);
  }

  void _onManagerChanged() {
    state = UploadManagerState(_manager);
  }
}