import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/file_item.dart';
import '../models/user.dart';
import 'api_provider.dart';

/// 侧边栏快速入口分类（对应 Cloudreve v4 URI 搜索条件 name=扩展名&case_folding=）。
enum FileCategory {
  image('图片', [
    'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'heic', 'heif', 'svg',
  ]),
  video('视频', [
    'mp4', 'mkv', 'avi', 'mov', 'webm', 'm4v', 'ts', 'm3u8',
  ]),
  music('音乐', [
    'mp3', 'flac', 'wav', 'm4a', 'aac', 'ogg', 'ape',
  ]),
  doc('文档', [
    'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'pdf', 'txt', 'md', 'csv',
  ]);

  const FileCategory(this.label, this.extensions);

  final String label;
  final List<String> extensions;
}

/// 目录列表（family：按路径缓存）。
final directoryProvider =
    FutureProvider.family<DirectoryListing, String>((ref, path) {
  final api = ref.watch(apiProvider);
  return api.listFiles(path, pageSize: 500);
});

/// 分类文件列表（图片 / 视频 / 音乐 / 文档）。
///
/// Cloudreve v4 `/file` 支持在 URI 中附带搜索条件，例如：
/// `cloudreve://my?name=.jpg&case_folding=`。这里按每个扩展名并行查询后
/// 按文件路径去重合并，再按文件名排序。
final categoryFilesProvider =
    FutureProvider.family<List<FileItem>, FileCategory>((ref, category) async {
  final api = ref.watch(apiProvider);
  final results = await Future.wait(category.extensions.map((ext) {
    return api.listFiles(
      'cloudreve://my?name=.$ext&case_folding=',
      pageSize: 500,
    );
  }));
  final seen = <String>{};
  final files = <FileItem>[];
  for (final listing in results) {
    for (final file in listing.files) {
      if (seen.add(file.path)) files.add(file);
    }
  }
  files.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return files;
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
