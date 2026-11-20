import 'package:cloudreve_view/core/i18n/app_language.dart';
import 'package:cloudreve_view/core/i18n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLocalizations.t', () {
    const zh = AppLocalizations(Locale('zh'));
    const en = AppLocalizations(Locale('en'));

    test('中文直接返回原文', () {
      expect(zh.t('我的文件'), '我的文件');
      expect(zh.t('设置'), '设置');
    });

    test('英文查表翻译', () {
      expect(en.t('我的文件'), 'My Files');
      expect(en.t('设置'), 'Settings');
    });

    test('未翻译的文案回退中文', () {
      expect(en.t('这段文案还没翻译'), '这段文案还没翻译');
    });

    test('占位符在两种语言下都会替换', () {
      expect(
        zh.t('当前：{label}', args: {'label': '简体中文'}),
        '当前：简体中文',
      );
      expect(
        en.t('当前：{label}', args: {'label': 'English'}),
        'Current: English',
      );
      expect(
        en.t('发现新版本 {version}', args: {'version': '1.0.0'}),
        'New version 1.0.0 available',
      );
    });
  });

  group('AppLanguage', () {
    test('持久化值解析', () {
      expect(AppLanguage.fromValue('zh'), AppLanguage.zh);
      expect(AppLanguage.fromValue('en'), AppLanguage.en);
      expect(AppLanguage.fromValue('system'), AppLanguage.system);
      expect(AppLanguage.fromValue('ja'), AppLanguage.system);
      expect(AppLanguage.fromValue(null), AppLanguage.system);
    });

    test('只给显式语言返回 locale', () {
      expect(AppLanguage.system.locale, isNull);
      expect(AppLanguage.zh.locale, const Locale('zh'));
      expect(AppLanguage.en.locale, const Locale('en'));
    });
  });

  group('delegate 与系统语言解析', () {
    test('支持中文和英文', () {
      expect(AppLocalizations.delegate.isSupported(const Locale('zh')), isTrue);
      expect(AppLocalizations.delegate.isSupported(const Locale('en')), isTrue);
      expect(
          AppLocalizations.delegate.isSupported(const Locale('ja')), isFalse);
    });

    test('系统语言不是中文时回退英文', () {
      expect(AppLocalizations.resolveLocale(const Locale('zh', 'CN')),
          const Locale('zh'));
      expect(AppLocalizations.resolveLocale(const Locale('en', 'US')),
          const Locale('en'));
      expect(AppLocalizations.resolveLocale(const Locale('ja')),
          const Locale('en'));
      expect(AppLocalizations.resolveLocale(null), const Locale('en'));
    });
  });

  group('全局 tr()', () {
    testWidgets('跟随全局语言输出文案', (tester) async {
      final previous = appL10n;
      addTearDown(() => appL10n = previous);

      appL10n = const AppLocalizations(Locale('en'));
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Text(tr('设置')))),
      );
      expect(find.text('Settings'), findsOneWidget);

      appL10n = const AppLocalizations(Locale('zh'));
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Text(tr('设置')))),
      );
      expect(find.text('设置'), findsOneWidget);
    });
  });
}
