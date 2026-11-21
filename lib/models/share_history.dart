import 'site.dart';

/// 打开过的分享记录（本地持久化）。
class ShareHistoryEntry {
  final Site site;
  final String shareId;
  final String? password;
  final String? name;
  final String? owner;
  final DateTime openedAt;

  const ShareHistoryEntry({
    required this.site,
    required this.shareId,
    this.password,
    this.name,
    this.owner,
    required this.openedAt,
  });

  /// 同一站点下同一个分享只保留一条记录。
  String get id => '${site.id}|$shareId';

  /// 历史列表显示的名称；没有分享名称时退回分享 ID。
  String get displayName {
    final value = name?.trim() ?? '';
    return value.isEmpty ? shareId : value;
  }

  /// 展示用的分享地址（不显示密码）。
  String get displayUrl => '${site.normalizedBaseUrl}/s/$shareId';

  /// 带密码的完整分享地址。
  String get url {
    final pwd = password == null || password!.isEmpty
        ? ''
        : '/${Uri.encodeComponent(password!)}';
    return '${site.normalizedBaseUrl}/s/$shareId$pwd';
  }

  Map<String, dynamic> toJson() => {
        'site': site.toJson(),
        'shareId': shareId,
        'password': password,
        'name': name,
        'owner': owner,
        'openedAt': openedAt.toIso8601String(),
      };

  factory ShareHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ShareHistoryEntry(
      site: Site.fromJson(json['site'] as Map<String, dynamic>),
      shareId: json['shareId'] as String? ?? '',
      password: json['password'] as String?,
      name: json['name'] as String?,
      owner: json['owner'] as String?,
      openedAt: DateTime.tryParse(json['openedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
