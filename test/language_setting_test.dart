import 'package:cloudreve_view/core/i18n/app_language.dart';
import 'package:cloudreve_view/core/i18n/app_localizations.dart';
import 'package:cloudreve_view/core/storage/app_storage.dart';
import 'package:cloudreve_view/providers/settings_provider.dart';
import 'package:cloudreve_view/widgets/settings/language_setting_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 只改内存状态，避免测试里读本地存储。
class _FakeSettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();

  @override
  Future<void> setLanguage(AppLanguage language) async {
    state = state.copyWith(language: language);
  }
}

void main() {
  group('语言持久化', () {
    test('默认跟随系统，可写入与读回', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = AppStorage(prefs, const FlutterSecureStorage());
      expect(storage.getLanguage(), 'system');
      await storage.setLanguage('en');
      expect(storage.getLanguage(), 'en');
    });
  });

  group('设置页语言切换', () {
    Future<void> pumpRow(WidgetTester tester, Locale locale) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsProvider.overrideWith(_FakeSettings.new)],
          child: MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const Scaffold(body: LanguageSettingRow()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('英文界面显示英文语言行', (tester) async {
      await pumpRow(tester, const Locale('en'));
      expect(find.text('Language'), findsOneWidget);
      expect(find.text('Current: System'), findsOneWidget);
    });

    testWidgets('选择 English 后设置更新', (tester) async {
      await pumpRow(tester, const Locale('zh'));

      // 默认：跟随系统。
      expect(find.text('语言'), findsOneWidget);
      expect(find.text('当前：跟随系统'), findsOneWidget);

      await tester.tap(find.text('当前：跟随系统'));
      await tester.pumpAndSettle();
      expect(find.text('English'), findsOneWidget);

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(find.text('当前：English'), findsOneWidget);
    });
  });
}
