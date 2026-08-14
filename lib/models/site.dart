import 'dart:convert';

/// 一个 Cloudreve v4 站点。
class Site {
  final String id;
  final String name;
  final String baseUrl;
  final bool skipTlsVerify;

  const Site({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.skipTlsVerify = false,
  });

  /// 去掉末尾斜杠的基地址，例如 https://v.timerunis.cn
  String get normalizedBaseUrl =>
      baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  /// API 基地址：https://host/api/v4
  String get apiBase => '$normalizedBaseUrl/api/v4';

  Site copyWith({String? id, String? name, String? baseUrl, bool? skipTlsVerify}) =>
      Site(
        id: id ?? this.id,
        name: name ?? this.name,
        baseUrl: baseUrl ?? this.baseUrl,
        skipTlsVerify: skipTlsVerify ?? this.skipTlsVerify,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'skipTlsVerify': skipTlsVerify,
      };

  factory Site.fromJson(Map<String, dynamic> json) => Site(
        id: json['id'] as String,
        name: json['name'] as String,
        baseUrl: json['baseUrl'] as String,
        skipTlsVerify: json['skipTlsVerify'] as bool? ?? false,
      );

  static String encodeList(List<Site> sites) =>
      jsonEncode(sites.map((e) => e.toJson()).toList());

  static List<Site> decodeList(String source) {
    final data = jsonDecode(source) as List<dynamic>;
    return data
        .map((e) => Site.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  bool operator ==(Object other) =>
      other is Site &&
      other.id == id &&
      other.name == name &&
      other.baseUrl == baseUrl &&
      other.skipTlsVerify == skipTlsVerify;

  @override
  int get hashCode => Object.hash(id, name, baseUrl, skipTlsVerify);
}
