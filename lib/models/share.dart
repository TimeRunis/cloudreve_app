/// Cloudreve v4 分享链接。
class ShareLink {
  final String id;
  final String name;
  final int visited;
  final int downloaded;
  final int price;
  final bool unlocked;
  final int sourceType;
  final String? sourceUri;
  final String createdAt;
  final bool expired;
  final String url;
  final bool? isPrivate;
  final String? password;
  final bool? shareView;
  final String? ownerNickname;
  final String? ownerEmail;

  const ShareLink({
    required this.id,
    required this.name,
    required this.visited,
    required this.downloaded,
    required this.price,
    required this.unlocked,
    required this.sourceType,
    this.sourceUri,
    required this.createdAt,
    required this.expired,
    required this.url,
    this.isPrivate,
    this.password,
    this.shareView,
    this.ownerNickname,
    this.ownerEmail,
  });

  bool get isFolder => sourceType == 1;

  factory ShareLink.fromJson(Map<String, dynamic> json) => ShareLink(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        visited: (json['visited'] as num?)?.toInt() ?? 0,
        downloaded: (json['downloaded'] as num?)?.toInt() ?? 0,
        price: (json['price'] as num?)?.toInt() ?? 0,
        unlocked: json['unlocked'] as bool? ?? false,
        sourceType: (json['source_type'] as num?)?.toInt() ?? 1,
        sourceUri: json['source_uri'] as String?,
        createdAt: json['created_at'] as String? ?? '',
        expired: json['expired'] as bool? ?? false,
        url: json['url'] as String? ?? '',
        isPrivate: json['is_private'] as bool?,
        password: json['password'] as String?,
        shareView: json['share_view'] as bool?,
        ownerNickname: json['owner'] is Map
            ? (json['owner'] as Map)['nickname'] as String?
            : null,
        ownerEmail: json['owner'] is Map
            ? (json['owner'] as Map)['email'] as String?
            : null,
      );
}