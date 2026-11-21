import 'dart:math';

import 'package:flutter/foundation.dart';

/// 语义化版本（SemVer 2.0）。
///
/// 既用于解析已安装应用的 `versionName`（例如 `1.0.0-beta.2`），也用于
/// 解析 GitHub 发布 tag（可能是 `v1.0.0`），两边统一成同一种可比对象。
class AppVersion implements Comparable<AppVersion> {
  final int major;
  final int minor;
  final int patch;

  /// 预发布标识：`1.0.0-beta.2` → `['beta', '2']`；正式版为空。
  final List<String> prerelease;

  /// 规范化后的版本字符串（去掉前缀 v、缺省段补 0 之前的原始写法）。
  final String raw;

  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.prerelease,
    required this.raw,
  });

  static final RegExp _pattern = RegExp(
    r'^[vV]?(\d+)(?:\.(\d+))?(?:\.(\d+))?'
    r'(?:-([0-9A-Za-z][0-9A-Za-z.\-]*))?'
    r'(?:\+[0-9A-Za-z.\-]+)?$',
  );

  /// 解析失败（不是版本号）时返回 null。
  static AppVersion? tryParse(String? input) {
    final text = (input ?? '').trim();
    if (text.isEmpty) return null;
    final match = _pattern.firstMatch(text);
    if (match == null) return null;
    final prerelease = (match.group(4) ?? '')
        .split('.')
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    return AppVersion(
      major: int.parse(match.group(1)!),
      minor: int.tryParse(match.group(2) ?? '') ?? 0,
      patch: int.tryParse(match.group(3) ?? '') ?? 0,
      prerelease: prerelease,
      raw: _normalizeRaw(text),
    );
  }

  /// `V1.0` → `1.0`（只去掉前缀 v，其余保持原样，便于原样展示）。
  static String _normalizeRaw(String text) {
    if (text.startsWith('v') || text.startsWith('V')) {
      return text.substring(1);
    }
    return text;
  }

  bool get isPrerelease => prerelease.isNotEmpty;

  /// 是否比 [other] 新。
  bool isNewerThan(AppVersion other) => compareTo(other) > 0;

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    // 正式版 > 预发布版。
    if (prerelease.isEmpty && other.prerelease.isEmpty) return 0;
    if (prerelease.isEmpty) return 1;
    if (other.prerelease.isEmpty) return -1;
    final length = min(prerelease.length, other.prerelease.length);
    for (var i = 0; i < length; i++) {
      final left = prerelease[i];
      final right = other.prerelease[i];
      final leftNumber = int.tryParse(left);
      final rightNumber = int.tryParse(right);
      int result;
      if (leftNumber != null && rightNumber != null) {
        result = leftNumber.compareTo(rightNumber);
      } else if (leftNumber != null) {
        // 数字标识优先级低于字母标识。
        result = -1;
      } else if (rightNumber != null) {
        result = 1;
      } else {
        result = left.compareTo(right);
      }
      if (result != 0) return result;
    }
    return prerelease.length.compareTo(other.prerelease.length);
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;
  bool operator <(AppVersion other) => compareTo(other) < 0;
  bool operator >=(AppVersion other) => compareTo(other) >= 0;
  bool operator <=(AppVersion other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) =>
      other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, prerelease.join('.'));

  @override
  String toString() => raw;
}

/// 远端的一个版本发布（GitHub Release）。
class AppRelease {
  /// 原始 tag，例如 `1.0.0-beta.3` 或 `v1.0.0-beta.3`。
  final String tag;

  /// 解析后的版本号。
  final AppVersion version;

  /// 发布标题（没填标题时 GitHub 用 tag 作为标题）。
  final String title;

  /// 更新说明（Markdown，来自 GitHub Release 的 body）。
  final String notes;

  /// 发布页地址。
  final String pageUrl;

  /// Android APK 直链；解析不到资产时为 null（此时只能打开发布页）。
  final String? downloadUrl;

  /// APK 大小（字节），未知为 null。
  final int? size;

  /// iOS IPA 直链；发布里没有 IPA 时为 null。
  final String? ipaUrl;

  /// IPA 大小（字节），未知为 null。
  final int? ipaSize;

  final DateTime? publishedAt;

  /// 是否为预发布版本。
  final bool isPrerelease;

  const AppRelease({
    required this.tag,
    required this.version,
    required this.title,
    required this.notes,
    required this.pageUrl,
    this.downloadUrl,
    this.size,
    this.ipaUrl,
    this.ipaSize,
    this.publishedAt,
    this.isPrerelease = false,
  });

  /// 展示用版本号（`versionName` 风格，不带前缀 v）。
  String get versionLabel => version.raw;

  bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  /// 当前平台是否有可下载的安装包。
  bool get hasPlatformPackage {
    final url = platformDownloadUrl;
    return url != null && url.isNotEmpty;
  }

  /// 当前平台对应的安装包直链。
  String? get platformDownloadUrl => isIOS ? ipaUrl : downloadUrl;

  /// 当前平台对应的安装包大小。
  int? get platformSize => isIOS ? ipaSize : size;

  /// 当前平台安装包文件名。
  String? get assetName {
    final url = platformDownloadUrl;
    if (url == null || url.isEmpty) return null;
    final segments = Uri.tryParse(url)?.pathSegments ?? const <String>[];
    if (segments.isEmpty) return null;
    return segments.last;
  }

  AppRelease copyWith({
    String? tag,
    AppVersion? version,
    String? title,
    String? notes,
    String? pageUrl,
    String? downloadUrl,
    int? size,
    String? ipaUrl,
    int? ipaSize,
    DateTime? publishedAt,
    bool? isPrerelease,
  }) =>
      AppRelease(
        tag: tag ?? this.tag,
        version: version ?? this.version,
        title: title ?? this.title,
        notes: notes ?? this.notes,
        pageUrl: pageUrl ?? this.pageUrl,
        downloadUrl: downloadUrl ?? this.downloadUrl,
        size: size ?? this.size,
        ipaUrl: ipaUrl ?? this.ipaUrl,
        ipaSize: ipaSize ?? this.ipaSize,
        publishedAt: publishedAt ?? this.publishedAt,
        isPrerelease: isPrerelease ?? this.isPrerelease,
      );

  @override
  String toString() => 'AppRelease($tag, apk: $downloadUrl, ipa: $ipaUrl)';
}
