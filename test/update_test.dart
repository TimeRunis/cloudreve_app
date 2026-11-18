import 'dart:convert';

import 'package:cloudreve_view/core/update/update_service.dart';
import 'package:cloudreve_view/models/app_release.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppVersion 比较', () {
    AppVersion v(String input) => AppVersion.tryParse(input)!;

    test('解析合法版本号', () {
      final version = v('v1.2.3-beta.4');
      expect(version.major, 1);
      expect(version.minor, 2);
      expect(version.patch, 3);
      expect(version.prerelease, ['beta', '4']);
      expect(version.raw, '1.2.3-beta.4');
      expect(version.isPrerelease, isTrue);
    });

    test('拒绝非法输入', () {
      expect(AppVersion.tryParse(''), isNull);
      expect(AppVersion.tryParse('latest'), isNull);
      expect(AppVersion.tryParse(null), isNull);
    });

    test('缺少段时按 0 处理', () {
      expect(v('1.2'), equals(v('1.2.0')));
      expect(v('1'), equals(v('1.0.0')));
    });

    test('预发布序号按数字比较', () {
      expect(v('1.0.0-beta.10') > v('1.0.0-beta.2'), isTrue);
      expect(v('1.0.0-beta.2') < v('1.0.0-beta.3'), isTrue);
    });

    test('正式版高于同号预发布版', () {
      expect(v('1.0.0') > v('1.0.0-rc.1'), isTrue);
      expect(v('1.0.0-beta.1') < v('1.0.0'), isTrue);
    });

    test('主次版本优先于预发布标识', () {
      expect(v('1.0.1-beta.1') > v('1.0.0'), isTrue);
      expect(v('1.1.0-beta.1') > v('1.0.9'), isTrue);
    });
  });

  group('更新说明转换', () {
    test('Markdown 去标记', () {
      const md = '## 新增\n- **检查更新**\n- 修复 [问题](https://example.com)\n';
      final text = UpdateService.plainTextFromMarkdown(md);
      expect(text, contains('新增'));
      expect(text, contains('检查更新'));
      expect(text, contains('修复 问题'));
      expect(text, isNot(contains('##')));
      expect(text, isNot(contains('**')));
      expect(text, isNot(contains('https://example.com')));
    });

    test('Atom 里的转义 HTML 解实体再去标签', () {
      const html = '&lt;p&gt;测试版&lt;/p&gt;'
          '&lt;ul&gt;&lt;li&gt;修复 A&amp;B&lt;/li&gt;&lt;/ul&gt;';
      final text = UpdateService.plainTextFromHtml(html);
      expect(text, contains('测试版'));
      expect(text, contains('· 修复 A&B'));
      expect(text, isNot(contains('&lt;')));
    });
  });

  group('解析 GitHub API 发布列表', () {
    test('跳过草稿、挑选 APK 资产、解析说明', () {
      final json = jsonDecode('''
      [
        {
          "tag_name": "1.0.0-beta.3",
          "name": "Beta 3",
          "body": "### 新功能\\n- 检查更新",
          "html_url": "https://github.com/TimeRunis/cloudreve_app/releases/tag/1.0.0-beta.3",
          "published_at": "2026-11-20T10:00:00Z",
          "prerelease": true,
          "draft": false,
          "assets": [
            {"name": "notes.txt", "browser_download_url": "https://example.com/notes.txt", "size": 10},
            {"name": "cloudreve-1.0.0-beta.3.apk", "browser_download_url": "https://example.com/cloudreve-1.0.0-beta.3.apk", "size": 25913839}
          ]
        },
        {
          "tag_name": "1.0.0-beta.4",
          "draft": true,
          "assets": []
        }
      ]
      ''');
      final releases = UpdateService.parseApiReleases(json);
      expect(releases, hasLength(1));
      final release = releases.single;
      expect(release.versionLabel, '1.0.0-beta.3');
      expect(release.title, 'Beta 3');
      expect(release.notes, contains('检查更新'));
      expect(release.downloadUrl, endsWith('cloudreve-1.0.0-beta.3.apk'));
      expect(release.size, 25913839);
      expect(release.isPrerelease, isTrue);
    });
  });

  group('解析 Releases Atom', () {
    test('从 tag 链接取版本并解析说明', () {
      const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <entry>
    <id>tag:github.com,2008:Repository/886223873/1.0.0-beta.2</id>
    <updated>2026-11-18T14:43:59Z</updated>
    <link rel="alternate" type="text/html" href="https://github.com/TimeRunis/cloudreve_app/releases/tag/1.0.0-beta.2"/>
    <title>1.0.0-beta.2</title>
    <content type="html">&lt;p&gt;测试版&lt;/p&gt;</content>
  </entry>
</feed>
''';
      final releases = UpdateService.parseAtomEntries(xml);
      expect(releases, hasLength(1));
      final release = releases.single;
      expect(release.versionLabel, '1.0.0-beta.2');
      expect(release.notes, '测试版');
      expect(release.pageUrl, contains('/releases/tag/1.0.0-beta.2'));
      expect(release.publishedAt, isNotNull);
      expect(release.downloadUrl, isNull);
    });
  });
}
