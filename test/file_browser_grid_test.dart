import 'package:cloudreve_view/models/file_item.dart';
import 'package:cloudreve_view/providers/settings_provider.dart';
import 'package:cloudreve_view/widgets/file/folder_card.dart';
import 'package:cloudreve_view/widgets/file_browser/file_browser_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

FileItem _folder(String name) => FileItem.fromJson({
      'type': 1,
      'id': name,
      'name': name,
      'path': 'cloudreve://my/$name',
    });

FileItem _file(String name) => FileItem.fromJson({
      'type': 0,
      'id': name,
      'name': name,
      'path': 'cloudreve://my/$name',
      'size': 1024,
    });

void main() {
  Future<void> pumpBrowser(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentSiteProvider.overrideWithValue(null)],
        child: MaterialApp(
          home: Scaffold(
            body: FileBrowserView(
              files: [
                _folder('pictures'),
                _folder('111'),
                _folder('一个名字很长的文件夹'),
                _file('note.txt'),
              ],
              viewMode: 'grid',
              showThumbnails: false,
              selectedPaths: const {},
              onOpen: (_) {},
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  SliverGridDelegateWithFixedCrossAxisCount gridDelegateOf(
    WidgetTester tester,
    int index,
  ) {
    final grid = tester.widget<GridView>(find.byType(GridView).at(index));
    return grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
  }

  testWidgets('手机宽度仍是一行 2 张卡片', (tester) async {
    await pumpBrowser(tester, 400);
    expect(gridDelegateOf(tester, 0).crossAxisCount, 2);
    expect(gridDelegateOf(tester, 1).crossAxisCount, 2);
  });

  testWidgets('宽屏下一行 3 张卡片', (tester) async {
    await pumpBrowser(tester, 900);
    expect(gridDelegateOf(tester, 0).crossAxisCount, 3);
    expect(gridDelegateOf(tester, 1).crossAxisCount, 3);
  });

  testWidgets('超宽屏下一行 4 张卡片', (tester) async {
    await pumpBrowser(tester, 1200);
    expect(gridDelegateOf(tester, 0).crossAxisCount, 4);
    expect(gridDelegateOf(tester, 1).crossAxisCount, 4);
  });

  testWidgets('宽屏断点边界：600 起 3 列、1000 起 4 列', (tester) async {
    await pumpBrowser(tester, 599);
    expect(gridDelegateOf(tester, 0).crossAxisCount, 2);
    await pumpBrowser(tester, 600);
    expect(gridDelegateOf(tester, 0).crossAxisCount, 3);
    await pumpBrowser(tester, 999);
    expect(gridDelegateOf(tester, 0).crossAxisCount, 3);
    await pumpBrowser(tester, 1000);
    expect(gridDelegateOf(tester, 0).crossAxisCount, 4);
  });

  testWidgets('文件夹卡片图标放大到 24', (tester) async {
    await pumpBrowser(tester, 1200);
    final card = tester.widget<FolderCard>(find.byType(FolderCard).first);
    expect(card.folder.name, 'pictures');
    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byType(FolderCard).first,
        matching: find.byIcon(Icons.folder),
      ),
    );
    expect(icon.size, 24);
  });

  testWidgets('宽屏 4 列下长文件名不溢出', (tester) async {
    await pumpBrowser(tester, 1200);
    expect(tester.takeException(), isNull);
  });
}
