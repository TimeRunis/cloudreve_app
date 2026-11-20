import 'package:cloudreve_view/models/file_item.dart';
import 'package:cloudreve_view/models/site_config.dart';
import 'package:cloudreve_view/models/user.dart';
import 'package:cloudreve_view/providers/directory_provider.dart';
import 'package:cloudreve_view/providers/settings_provider.dart';
import 'package:cloudreve_view/providers/site_config_provider.dart';
import 'package:cloudreve_view/widgets/navigation/sidebar_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
}

FileItem _shortcut(String name) => FileItem.fromJson({
      'type': 1,
      'id': name,
      'name': name,
      'path': 'cloudreve://my/$name',
      'metadata': {
        'sys:shared_redirect': 'cloudreve://geouP:cangku@share',
        'sys:shared_owner': 'dyhK',
      },
    });

void main() {
  Future<void> pumpSidebar(
    WidgetTester tester, {
    required bool active,
    required VoidCallback onSharedWithMe,
    required ValueChanged<FileItem> onNavigate,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_FakeSettings.new),
          currentSiteProvider.overrideWithValue(null),
          siteConfigProvider.overrideWith(
            (ref) async => const SiteConfig(title: '测试站点'),
          ),
          directoryProvider.overrideWith(
            (ref, query) async => const DirectoryListing(files: []),
          ),
          capacityProvider.overrideWith(
            (ref) async => const Capacity(
              total: 1024,
              used: 512,
              storagePackTotal: 0,
            ),
          ),
          sharedWithMeProvider.overrideWith(
            (ref) async => [_shortcut('pictures'), _shortcut('111')],
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SidebarPanel(
                sharedWithMeActive: active,
                onSharedWithMe: onSharedWithMe,
                onNavigate: onNavigate,
                onPlaceholder: () {},
                onCycleTheme: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('与我共享作为分组展示一级分享快捷方式', (tester) async {
    await pumpSidebar(
      tester,
      active: true,
      onSharedWithMe: () {},
      onNavigate: (_) {},
    );

    expect(find.text('与我共享'), findsOneWidget);
    expect(find.text('pictures'), findsOneWidget);
    expect(find.text('111'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('点击分组主体切换视图，点击子项打开分享', (tester) async {
    var selected = false;
    FileItem? opened;
    await pumpSidebar(
      tester,
      active: false,
      onSharedWithMe: () => selected = true,
      onNavigate: (file) => opened = file,
    );

    // 默认收起：不请求分组数据。
    expect(find.text('pictures'), findsNothing);

    await tester.tap(find.text('与我共享'));
    await tester.pumpAndSettle();
    expect(selected, isTrue);
    expect(find.text('pictures'), findsOneWidget);

    await tester.tap(find.text('pictures'));
    await tester.pumpAndSettle();
    expect(opened?.name, 'pictures');
  });
}
