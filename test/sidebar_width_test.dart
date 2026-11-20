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

/// 避免读本地存储：直接用默认设置。
class _FakeSettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
}

void main() {
  Future<void> pumpSidebar(WidgetTester tester, {required double width}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      ProviderScope(
        key: ValueKey(width),
        overrides: [
          settingsProvider.overrideWith(_FakeSettings.new),
          currentSiteProvider.overrideWithValue(null),
          siteConfigProvider.overrideWith(
            (ref) async => const SiteConfig(title: '测试站点'),
          ),
          directoryProvider.overrideWith(
            (ref, query) async => DirectoryListing(files: [
              FileItem.fromJson({
                'type': 1,
                'id': 'folder',
                'name': 'v',
                'path': 'cloudreve://my/v',
              }),
            ]),
          ),
          capacityProvider.overrideWith(
            (ref) async => const Capacity(
              total: 1024 * 1024 * 1024,
              used: 100 * 1024 * 1024,
              storagePackTotal: 0,
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SidebarPanel(
                onNavigate: (_) {},
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

  double sidebarWidth(WidgetTester tester) =>
      tester.getSize(find.byType(SidebarPanel)).width;

  testWidgets('窄屏宽度为屏幕的 75%', (tester) async {
    await pumpSidebar(tester, width: 400);
    expect(sidebarWidth(tester), closeTo(400 * 0.75, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('宽屏宽度为屏幕的 40%', (tester) async {
    await pumpSidebar(tester, width: 800);
    expect(sidebarWidth(tester), closeTo(800 * 0.40, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('超宽屏宽度为屏幕的 30%', (tester) async {
    await pumpSidebar(tester, width: 1200);
    expect(sidebarWidth(tester), closeTo(1200 * 0.30, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('断点边界：600 起 40%，1000 起 30%', (tester) async {
    await pumpSidebar(tester, width: 599);
    expect(sidebarWidth(tester), closeTo(599 * 0.75, 0.01));

    await pumpSidebar(tester, width: 600);
    expect(sidebarWidth(tester), closeTo(600 * 0.40, 0.01));

    await pumpSidebar(tester, width: 999);
    expect(sidebarWidth(tester), closeTo(999 * 0.40, 0.01));

    await pumpSidebar(tester, width: 1000);
    expect(sidebarWidth(tester), closeTo(1000 * 0.30, 0.01));
  });

  testWidgets('侧边栏不再显示站点名', (tester) async {
    await pumpSidebar(tester, width: 800);
    expect(find.text('测试站点'), findsNothing);
  });
}
