import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/app_storage.dart';

/// 全局存储实例（在 main 中通过 override 注入）。
final storageProvider = Provider<AppStorage>((ref) {
  throw UnimplementedError('storageProvider 需在 main 中覆盖注入');
});
