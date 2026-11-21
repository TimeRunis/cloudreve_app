import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../models/app_release.dart';
import '../log/app_log.dart';

/// 检查更新：从 GitHub Releases 读取最新发布。
///
/// 两个数据源按顺序尝试：
/// 1. GitHub API：能拿到精确的安装包地址、体积与完整更新说明；
/// 2. Releases Atom 订阅：无需鉴权、没有调用频率限制，作为 API 被限流
///    （匿名调用每小时 60 次，共享出口 IP 很容易耗尽）时的兜底。
///
/// Atom 源里没有资产列表，因此按发布约定 `cloudreve-<tag>.apk` 探测安装包，
/// 探测不到时只提供「打开发布页」。
class UpdateService {
  UpdateService({required this.dio, this.repo = defaultRepo});

  /// 发布仓库（owner/name）。
  static const String defaultRepo = 'TimeRunis/cloudreve_app';

  static const String _userAgent = 'Cloudreve-App';

  /// 更新说明展示上限，避免超长发布说明撑爆弹窗。
  static const int maxNotesLength = 4000;

  final Dio dio;
  final String repo;

  String get _apiUrl =>
      'https://api.github.com/repos/$repo/releases?per_page=20';
  String get _atomUrl => 'https://github.com/$repo/releases.atom';

  /// 最新发布；没有任何发布或两个数据源都失败时返回 null。
  Future<AppRelease?> fetchLatest() async {
    final apiReleases = await _fetchFromApi();
    if (apiReleases.isNotEmpty) return _newest(apiReleases);

    final atomReleases = await _fetchFromAtom();
    if (atomReleases.isEmpty) return null;
    return _resolveAsset(_newest(atomReleases));
  }

  // ---------- 数据源 ----------

  Future<List<AppRelease>> _fetchFromApi() async {
    try {
      final response = await dio.get<String>(
        _apiUrl,
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
            'User-Agent': _userAgent,
          },
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      final body = response.data;
      if (body == null || body.isEmpty) return const [];
      return parseApiReleases(jsonDecode(body));
    } catch (e) {
      AppLogger.log.w('[Update] GitHub API 不可用，改用 Atom：$e');
      return const [];
    }
  }

  Future<List<AppRelease>> _fetchFromAtom() async {
    try {
      final response = await dio.get<String>(
        _atomUrl,
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'Accept': 'application/atom+xml',
            'User-Agent': _userAgent,
          },
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      final body = response.data;
      if (body == null || body.isEmpty) return const [];
      return parseAtomEntries(body);
    } catch (e) {
      AppLogger.log.w('[Update] 读取 Releases Atom 失败：$e');
      return const [];
    }
  }

  /// Atom 源没有安装包信息：按命名约定探测体积（同时确认文件存在）。
  Future<AppRelease> _resolveAsset(AppRelease release) async {
    if (release.downloadUrl != null) return release;
    final candidates = _assetNameCandidates(release.tag);
    for (final name in candidates) {
      final url = _assetUrl(release.tag, name);
      final size = await _probeSize(url);
      if (size != null) {
        return release.copyWith(downloadUrl: url, size: size);
      }
    }
    // 探测失败（部分网络环境不支持 HEAD）时仍按约定给出安装包地址，
    // 保证手动检查和启动检查都能走应用内下载；真下载失败会提示打开发布页。
    return release.copyWith(
      downloadUrl: _assetUrl(release.tag, candidates.first),
    );
  }

  String _assetUrl(String tag, String name) =>
      'https://github.com/$repo/releases/download/'
      '${Uri.encodeComponent(tag)}/$name';

  List<String> _assetNameCandidates(String tag) {
    final names = <String>['cloudreve-$tag.apk'];
    if (tag.startsWith('v') || tag.startsWith('V')) {
      names.add('cloudreve-${tag.substring(1)}.apk');
    }
    return names;
  }

  Future<int?> _probeSize(String url) async {
    try {
      final response = await dio.head<void>(
        url,
        options: Options(
          followRedirects: true,
          receiveTimeout: const Duration(seconds: 10),
          headers: {'User-Agent': _userAgent},
          validateStatus: (code) => code != null && code >= 200 && code < 400,
        ),
      );
      if (response.statusCode != 200) return null;
      return int.tryParse(response.headers.value('content-length') ?? '');
    } catch (_) {
      return null;
    }
  }

  AppRelease _newest(List<AppRelease> releases) {
    var newest = releases.first;
    for (final release in releases.skip(1)) {
      if (release.version.compareTo(newest.version) > 0) newest = release;
    }
    return newest;
  }

  // ---------- 解析（无网络依赖，便于单测） ----------

  /// 解析 GitHub API `/repos/{owner}/{repo}/releases` 的 JSON。
  @visibleForTesting
  static List<AppRelease> parseApiReleases(dynamic json) {
    if (json is! List) return const [];
    final releases = <AppRelease>[];
    for (final item in json) {
      if (item is! Map) continue;
      if (item['draft'] == true) continue;
      final tag = (item['tag_name'] as String? ?? '').trim();
      final version = AppVersion.tryParse(tag);
      if (version == null) continue;

      String? downloadUrl;
      int? size;
      final asset = _pickApkAsset(item['assets'], version);
      if (asset != null) {
        downloadUrl = asset['browser_download_url'] as String?;
        size = (asset['size'] as num?)?.toInt();
      }

      final rawTitle = (item['name'] as String? ?? '').trim();
      releases.add(AppRelease(
        tag: tag,
        version: version,
        title: rawTitle.isEmpty ? version.raw : rawTitle,
        notes: normalizeNotes(item['body'] as String? ?? ''),
        pageUrl: item['html_url'] as String? ??
            'https://github.com/$defaultRepo/releases/tag/$tag',
        downloadUrl: downloadUrl,
        size: size,
        publishedAt:
            DateTime.tryParse(item['published_at'] as String? ?? '')?.toLocal(),
        isPrerelease: item['prerelease'] == true || version.isPrerelease,
      ));
    }
    return releases;
  }

  /// 从资产列表里挑 APK：优先文件名带版本号的（约定 `cloudreve-<版本>.apk`）。
  static Map? _pickApkAsset(dynamic assets, AppVersion version) {
    if (assets is! List) return null;
    Map? fallback;
    Map? matched;
    final versionText = version.raw.toLowerCase();
    for (final asset in assets) {
      if (asset is! Map) continue;
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (!name.endsWith('.apk')) continue;
      final url = asset['browser_download_url'] as String?;
      if (url == null || url.isEmpty) continue;
      fallback ??= asset;
      if (name.contains(versionText)) {
        matched = asset;
        break;
      }
    }
    return matched ?? fallback;
  }

  /// 解析 Releases Atom 订阅（`<entry>` 列表）。
  @visibleForTesting
  static List<AppRelease> parseAtomEntries(String xml) {
    final releases = <AppRelease>[];
    final entries =
        RegExp(r'<entry>(.*?)</entry>', dotAll: true).allMatches(xml);
    for (final entry in entries) {
      final body = entry.group(1) ?? '';
      final linkMatch = RegExp(r'/releases/tag/([^"<\s]+)').firstMatch(body);
      if (linkMatch == null) continue;
      final tag = Uri.decodeComponent(linkMatch.group(1)!);
      final version = AppVersion.tryParse(tag);
      if (version == null) continue;

      final titleMatch =
          RegExp(r'<title>(.*?)</title>', dotAll: true).firstMatch(body);
      final title = decodeHtmlEntities(titleMatch?.group(1) ?? '').trim();
      final contentMatch = RegExp(
        r'<content[^>]*type="html"[^>]*>(.*?)</content>',
        dotAll: true,
      ).firstMatch(body);
      final updatedMatch = RegExp(r'<updated>(.*?)</updated>').firstMatch(body);

      releases.add(AppRelease(
        tag: tag,
        version: version,
        title: title.isEmpty ? version.raw : title,
        notes: markdownFromHtml(contentMatch?.group(1) ?? ''),
        pageUrl: 'https://github.com/$defaultRepo/releases/tag/'
            '${Uri.encodeComponent(tag)}',
        publishedAt: DateTime.tryParse(updatedMatch?.group(1) ?? '')?.toLocal(),
        isPrerelease: version.isPrerelease,
      ));
    }
    return releases;
  }

  /// 规范化 Markdown 更新说明：统一换行、去行尾空白、压缩空行、限制长度。
  @visibleForTesting
  static String normalizeNotes(String markdown) {
    if (markdown.trim().isEmpty) return '';
    var text = markdown
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
        .replaceAll(RegExp(r'[ \t]+$', multiLine: true), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    if (text.length > maxNotesLength) {
      final cut = text.substring(0, maxNotesLength);
      final lastNewline = cut.lastIndexOf('\n');
      text =
          '${(lastNewline > 0 ? cut.substring(0, lastNewline) : cut).trimRight()}…';
    }
    return text;
  }

  /// GitHub 发布说明（HTML）→ Markdown。
  ///
  /// Atom 里的 HTML 是转义过的（`&lt;p&gt;`），所以先解实体再转换；
  /// 常见块级 / 行内标签尽量还原成 Markdown，交给界面统一渲染。
  @visibleForTesting
  static String markdownFromHtml(String html) {
    if (html.trim().isEmpty) return '';
    var text = decodeHtmlEntities(html);
    // 行内样式先转，避免块级替换后丢失。
    text = text.replaceAllMapped(
      RegExp(r'<(?:strong|b)[^>]*>(.*?)</(?:strong|b)>',
          dotAll: true, caseSensitive: false),
      (m) => '**${m[1]!.trim()}**',
    );
    text = text.replaceAllMapped(
      RegExp(r'<(?:em|i)[^>]*>(.*?)</(?:em|i)>',
          dotAll: true, caseSensitive: false),
      (m) => '*${m[1]!.trim()}*',
    );
    text = text.replaceAllMapped(
      RegExp(r'<code[^>]*>(.*?)</code>', dotAll: true, caseSensitive: false),
      (m) => '`${m[1]!.trim()}`',
    );
    text = text.replaceAllMapped(
      RegExp(r'<a[^>]*href="([^"]*)"[^>]*>(.*?)</a>',
          dotAll: true, caseSensitive: false),
      (m) => '[${m[2]!.trim()}](${m[1]!})',
    );
    text = text.replaceAllMapped(
      RegExp(r'<h([1-6])[^>]*>(.*?)</h\1>', dotAll: true, caseSensitive: false),
      (m) => '\n${'#' * int.parse(m[1]!)} ${m[2]!.trim()}\n',
    );
    text = text.replaceAllMapped(
      RegExp(r'<li[^>]*>(.*?)</li>', dotAll: true, caseSensitive: false),
      (m) => '\n- ${m[1]!.trim()}\n',
    );
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(
      RegExp(r'</?(?:p|div|ul|ol|tr|blockquote|section|article)[^>]*>',
          caseSensitive: false),
      '\n',
    );
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    return normalizeNotes(text);
  }

  /// 解码常见 HTML 实体（`&amp;` 放最后，避免二次解码）。
  @visibleForTesting
  static String decodeHtmlEntities(String text) {
    var result = text
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&hellip;', '…')
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&middot;', '·');
    result = result.replaceAllMapped(
        RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m[1]!)));
    result = result.replaceAllMapped(RegExp(r'&#[xX]([0-9a-fA-F]+);'),
        (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)));
    return result.replaceAll('&amp;', '&');
  }
}
