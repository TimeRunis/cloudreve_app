/// Cloudreve v4 文件/目录对象（来自 GET /file 的 files[]）。
class FileItem {
  /// 0 = 文件，1 = 文件夹。
  final int type;
  final String id;
  final String name;
  final String path;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int size;
  final Map<String, dynamic> metadata;
  final bool owned;

  const FileItem({
    required this.type,
    required this.id,
    required this.name,
    required this.path,
    this.createdAt,
    this.updatedAt,
    this.size = 0,
    this.metadata = const {},
    this.owned = true,
  });

  bool get isFolder => type == 1;
  bool get isFile => type == 0;

  /// 去掉 cloudreve://my 前缀后的路径。
  String get relativePath {
    const prefix = 'cloudreve://my';
    if (path.startsWith(prefix)) {
      return path.substring(prefix.length);
    }
    return path;
  }

  factory FileItem.fromJson(Map<String, dynamic> json) => FileItem(
        type: json['type'] as int? ?? 0,
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        path: json['path'] as String? ?? '',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
        size: (json['size'] as num?)?.toInt() ?? 0,
        metadata: json['metadata'] is Map<String, dynamic>
            ? json['metadata'] as Map<String, dynamic>
            : const {},
        owned: json['owned'] as bool? ?? true,
      );
}

/// 目录列表结果（GET /file 的 data）。
class DirectoryListing {
  final List<FileItem> files;
  final FileItem? parent;

  const DirectoryListing({required this.files, this.parent});

  factory DirectoryListing.fromJson(Map<String, dynamic> json) {
    final files = (json['files'] as List<dynamic>? ?? [])
        .map((e) => FileItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final parent = json['parent'] == null
        ? null
        : FileItem.fromJson(json['parent'] as Map<String, dynamic>);
    return DirectoryListing(files: files, parent: parent);
  }
}
