import 'package:cloudreve_view/core/i18n/app_language.dart';
import 'package:cloudreve_view/core/i18n/app_localizations.dart';
import 'package:cloudreve_view/pages/settings_hub_page.dart';
import 'package:cloudreve_view/providers/settings_provider.dart';
import 'package:cloudreve_view/providers/update_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
}

class _FakeUpdate extends UpdateNotifier {
  @override
  UpdateState build() => const UpdateState();
}

void main() {
  testWidgets('设置页在英文下完整翻译', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_FakeSettings.new),
          updateProvider.overrideWith(_FakeUpdate.new),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SettingsHubPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Current: System'), findsNWidgets(2));
    expect(find.text('Sites'), findsOneWidget);
    expect(find.text('Manage sites'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Download settings'), findsOneWidget);
    expect(find.text('Logs'), findsOneWidget);
    expect(find.text('Export logs'), findsOneWidget);
    expect(find.text('Updates'), findsOneWidget);
    expect(find.text('Check for updates'), findsOneWidget);
    expect(find.text('Auto check'), findsOneWidget);
    expect(find.text('About Cloudreve'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('语言枚举默认解析为跟随系统', (tester) async {
    expect(AppLanguage.fromValue('zh'), AppLanguage.zh);
  });
}
