import 'dart:convert';

import 'package:cloudreve_view/core/network/cloudreve_api.dart';
import 'package:cloudreve_view/models/file_item.dart';
import 'package:cloudreve_view/providers/settings_provider.dart';
import 'package:cloudreve_view/widgets/file/file_item_icon.dart';
import 'package:cloudreve_view/widgets/file/file_list_tile.dart';
import 'package:cloudreve_view/widgets/file/folder_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 服务端返回的两个真实条目：
/// - pictures：收藏的分享链接（metadata 里带 sys:shared_redirect / owner）
/// - 111：已分享出去的文件夹（顶层 shared 字段）
const String _listingJson = '''
[
  {
    "type": 1,
    "id": "mLXqHo",
    "name": "pictures",
    "created_at": "2026-11-18T23:39:14.991764809+08:00",
    "updated_at": "2026-11-18T23:40:24.662098576+08:00",
    "size": 0,
    "metadata": {
      "sys:shared_owner": "dyhK",
      "sys:shared_redirect": "cloudreve://geouP:cangku@share"
    },
    "path": "cloudreve://my/%E7%A6%BB%E7%BA%BF%E4%B8%8B%E8%BD%BD/pictures",
    "capability": "w8edAQ==",
    "owned": true,
    "primary_entity": "GoF1"
  },
  {
    "type": 1,
    "id": "9BD9TD",
    "name": "111",
    "created_at": "2026-11-18T23:40:55.300753108+08:00",
    "updated_at": "2026-11-18T23:40:55.300754276+08:00",
    "size": 0,
    "metadata": {},
    "path": "cloudreve://my/%E7%A6%BB%E7%BA%BF%E4%B8%8B%E8%BD%BD/111",
    "shared": true,
    "capability": "w8edAQ==",
    "owned": true,
    "primary_entity": "GoF1"
  }
]
''';

void main() {
  late FileItem shortcut;
  late FileItem sharedFolder;

  setUpAll(() {
    final list = (jsonDecode(_listingJson) as List)
        .map((e) => FileItem.fromJson(e as Map<String, dynamic>))
        .toList();
    shortcut = list[0];
    sharedFolder = list[1];
  });

  group('FileItem 分享字段', () {
    test('收藏的分享链接解析 metadata', () {
      expect(shortcut.isShareShortcut, isTrue);
      expect(shortcut.sharedRedirect, 'cloudreve://geouP:cangku@share');
      expect(shortcut.sharedOwner, 'dyhK');
      expect(shortcut.shared, isFalse);
    });

    test('已分享文件夹只有 shared 字段', () {
      expect(sharedFolder.isShareShortcut, isFalse);
      expect(sharedFolder.sharedRedirect, isNull);
      expect(sharedFolder.sharedOwner, isNull);
      expect(sharedFolder.shared, isTrue);
    });

    test('普通条目两个状态都不成立', () {
      final plain = FileItem.fromJson({
        'type': 1,
        'id': 'x',
        'name': '普通文件夹',
        'path': 'cloudreve://my/plain',
        'metadata': <String, dynamic>{},
      });
      expect(plain.isShareShortcut, isFalse);
      expect(plain.shared, isFalse);
    });

    test('metadata 里字段类型异常时按未设置处理', () {
      final weird = FileItem.fromJson({
        'type': 1,
        'id': 'x',
        'name': 'x',
        'path': 'cloudreve://my/x',
        'metadata': {'sys:shared_redirect': 42, 'sys:shared_owner': null},
      });
      expect(weird.isShareShortcut, isFalse);
      expect(weird.sharedOwner, isNull);
    });
  });

  group('分享 URI 解析', () {
    test('cloudreve://{id}:{password}@share', () {
      final parsed = parseShareLinkFromText(
        'cloudreve://geouP:cangku@share',
        'https://demo.cloudreve.org',
      );
      expect(parsed, isNotNull);
      expect(parsed!.shareId, 'geouP');
      expect(parsed.password, 'cangku');
    });

    test('无密码的分享 URI', () {
      final parsed = parseShareLinkFromText(
        'cloudreve://geouP@share',
        'https://demo.cloudreve.org',
      );
      expect(parsed!.shareId, 'geouP');
      expect(parsed.password, isNull);
    });
  });

  group('FileItemIcon 徽标', () {
    Future<void> pumpIcon(WidgetTester tester, FileItem file) async {
      await tester.pumpWidget(
        ProviderScope(
          // 头像需要站点地址；测试里置空，走分享图标兜底。
          overrides: [currentSiteProvider.overrideWithValue(null)],
          child: MaterialApp(
            home: Scaffold(
              body: Center(child: FileItemIcon(file: file, size: 24)),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('收藏的分享链接显示头像兜底徽标', (tester) async {
      await pumpIcon(tester, shortcut);
      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('已分享文件夹显示分享徽标', (tester) async {
      await pumpIcon(tester, sharedFolder);
      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('普通文件夹没有徽标', (tester) async {
      final plain = FileItem.fromJson({
        'type': 1,
        'id': 'x',
        'name': '普通文件夹',
        'path': 'cloudreve://my/plain',
      });
      await pumpIcon(tester, plain);
      expect(find.byIcon(Icons.share), findsNothing);
    });

    testWidgets('文件夹卡片 / 列表行带徽标不溢出', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [currentSiteProvider.overrideWithValue(null)],
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  FolderCard(
                    folder: shortcut,
                    isSelected: false,
                    onSelect: () {},
                    onOpen: () {},
                  ),
                  FolderCard(
                    folder: sharedFolder,
                    isSelected: false,
                    onSelect: () {},
                    onOpen: () {},
                  ),
                  FileListTile(
                    file: shortcut,
                    isSelected: false,
                    onSelect: () {},
                    onOpen: () {},
                  ),
                  FileListTile(
                    file: sharedFolder,
                    isSelected: false,
                    onSelect: () {},
                    onOpen: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.share), findsNWidgets(4));
    });
  });
}
