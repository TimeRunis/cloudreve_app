import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/file_item.dart';
import '../models/user.dart';
import 'api_provider.dart';

/// 侧边栏快速入口分类（对应 Cloudreve v4 URI 搜索条件 name=扩展名&case_folding=）。
enum FileCategory {
  image('图片', [
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
    'bmp',
    'heic',
    'heif',
    'svg',
  ]),
  video('视频', [
    'mp4',
    'mkv',
    'avi',
    'mov',
    'webm',
    'm4v',
    'ts',
    'm3u8',
  ]),
  music('音乐', [
    'mp3',
    'flac',
    'wav',
    'm4a',
    'aac',
    'ogg',
    'ape',
  ]),
  doc('文档', [
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'pdf',
    'txt',
    'md',
    'csv',
  ]);

  const FileCategory(this.label, this.extensions);

  final String label;
  final List<String> extensions;
}

/// 目录查询：路径 + 可选排序 + 分页大小。
///
/// [orderBy] 为空表示不指定排序，沿用服务端默认（避免改变既有展示顺序）。
class DirectoryQuery {
  final String path;
  final String? orderBy;
  final String? orderDirection;
  final int pageSize;

  const DirectoryQuery(
    this.path, {
    this.orderBy,
    this.orderDirection,
    this.pageSize = 500,
  });

  @override
  bool operator ==(Object other) =>
      other is DirectoryQuery &&
      other.path == path &&
      other.orderBy == orderBy &&
      other.orderDirection == orderDirection &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(path, orderBy, orderDirection, pageSize);
}

/// 全局搜索查询：关键字 + 排序 + 分页大小。
class SearchQuery {
  final String keyword;
  final String? orderBy;
  final String? orderDirection;
  final int pageSize;

  const SearchQuery(
    this.keyword, {
    this.orderBy,
    this.orderDirection,
    this.pageSize = 500,
  });

  @override
  bool operator ==(Object other) =>
      other is SearchQuery &&
      other.keyword == keyword &&
      other.orderBy == orderBy &&
      other.orderDirection == orderDirection &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(keyword, orderBy, orderDirection, pageSize);
}

/// 分类查询：分类 + 排序 + 分页大小。
class CategoryQuery {
  final FileCategory category;
  final String? orderBy;
  final String? orderDirection;
  final int pageSize;

  const CategoryQuery(
    this.category, {
    this.orderBy,
    this.orderDirection,
    this.pageSize = 500,
  });

  @override
  bool operator ==(Object other) =>
      other is CategoryQuery &&
      other.category == category &&
      other.orderBy == orderBy &&
      other.orderDirection == orderDirection &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(category, orderBy, orderDirection, pageSize);
}

/// 目录列表（family：按路径 + 排序 + 分页缓存）。
final directoryProvider =
    FutureProvider.family<DirectoryListing, DirectoryQuery>((ref, query) {
  final api = ref.watch(apiProvider);
  return api.listFiles(
    query.path,
    pageSize: query.pageSize,
    orderBy: query.orderBy,
    orderDirection: query.orderDirection,
  );
});

/// 分类文件列表（图片 / 视频 / 音乐 / 文档）。
///
/// Cloudreve v4 `/file` 支持在 URI 中附带搜索条件，例如：
/// `cloudreve://my?name=.jpg&case_folding=`。这里按每个扩展名并行查询后
/// 按文件路径去重合并 —— 合并后的顺序不完整，所以再按当前排序规则本地重排。
final categoryFilesProvider =
    FutureProvider.family<List<FileItem>, CategoryQuery>((ref, query) async {
  final api = ref.watch(apiProvider);
  final results = await Future.wait(query.category.extensions.map((ext) {
    return api.listFiles(
      'cloudreve://my?name=.$ext&case_folding=',
      pageSize: query.pageSize,
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
    (a, b) => compareFileItems(a, b, query.orderBy, query.orderDirection),
  );
  return files;
});

/// 全局文件搜索（在「我的文件」根目录下按文件名模糊匹配）。
///
/// 对应 Cloudreve v4 Web 端搜索请求：
/// `cloudreve://my/?name=<keyword>&case_folding=`；排序与分页由服务端处理。
final searchFilesProvider =
    FutureProvider.family<List<FileItem>, SearchQuery>((ref, query) async {
  final api = ref.watch(apiProvider);
  final encoded = Uri.encodeQueryComponent(query.keyword);
  final listing = await api.listFiles(
    'cloudreve://my/?name=$encoded&case_folding=',
    pageSize: query.pageSize,
    orderBy: query.orderBy,
    orderDirection: query.orderDirection,
  );
  return listing.files;
});

/// 按 `order_by` / `order_direction` 比较文件，供合并多批结果后本地重排。
///
/// 不指定排序时按文件名升序（与分类视图原有行为一致）。
int compareFileItems(
  FileItem a,
  FileItem b,
  String? orderBy,
  String? orderDirection,
) {
  final int result;
  switch (orderBy) {
    case 'size':
      result = a.size.compareTo(b.size);
    case 'updated_at':
      result = _compareTime(a.updatedAt, b.updatedAt);
    case 'created_at':
      result = _compareTime(a.createdAt, b.createdAt);
    default:
      result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }
  return orderDirection == 'desc' ? -result : result;
}

int _compareTime(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}

/// 存储容量。
final capacityProvider = FutureProvider<Capacity>((ref) {
  final api = ref.watch(apiProvider);
  return api.getCapacity();
});

/// 缩略图直链（family：按文件 URI 缓存，失败返回 null）。
final thumbnailUrlProvider = FutureProvider.family<String?, String>((
  ref,
  uri,
) async {
  final api = ref.watch(apiProvider);
  try {
    return await api.getThumbnailUrl(uri, width: 320, height: 320);
  } catch (_) {
    return null;
  }
});

/// 源文件直链（原图 / 下载用，family：按文件 URI 缓存，失败返回 null）。
final fileSourceUrlProvider = FutureProvider.family<String?, String>((
  ref,
  uri,
) async {
  final api = ref.watch(apiProvider);
  try {
    return await api.getFileSourceUrl(uri);
  } catch (_) {
    return null;
  }
});
