import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/file_item.dart';
import '../models/user.dart';
import 'api_provider.dart';

/// 目录列表（family：按路径缓存）。
final directoryProvider =
    FutureProvider.family<DirectoryListing, String>((ref, path) {
  final api = ref.watch(apiProvider);
  return api.listFiles(path, pageSize: 500);
});

/// 存储容量。
final capacityProvider = FutureProvider<Capacity>((ref) {
  final api = ref.watch(apiProvider);
  return api.getCapacity();
});

/// 缩略图直链（family：按文件 URI 缓存，失败返回 null）。
final thumbnailUrlProvider =
    FutureProvider.family<String?, String>((ref, uri) async {
  final api = ref.watch(apiProvider);
  try {
    return await api.getThumbnailUrl(uri, width: 320, height: 320);
  } catch (_) {
    return null;
  }
});

/// 源文件直链（原图 / 下载用，family：按文件 URI 缓存，失败返回 null）。
final fileSourceUrlProvider =
    FutureProvider.family<String?, String>((ref, uri) async {
  final api = ref.watch(apiProvider);
  try {
    return await api.getFileSourceUrl(uri);
  } catch (_) {
    return null;
  }
});
