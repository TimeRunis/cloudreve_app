import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_events.dart';
import 'core/i18n/app_localizations.dart';
import 'core/log/app_log.dart';
import 'core/network/tls_override.dart';
import 'core/storage/app_storage.dart';
import 'core/theme/app_theme.dart';
import 'pages/root_page.dart';
import 'providers/settings_provider.dart';
import 'providers/site_config_provider.dart';
import 'providers/storage_provider.dart';
import 'widgets/update/update_download_watcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogger.init();
  FlutterError.onError = (details) {
    AppLogger.log.e(
      '[FlutterError] ${details.exceptionAsString()}',
      error: details.exception,
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };
  installTlsTrustOverride();
  final storage = await AppStorage.create();
  await AppEventBus.init();
  AppLogger.log.i(tr('[App] 应用启动'));
  runApp(ProviderScope(
    overrides: [storageProvider.overrideWithValue(storage)],
    child: const CloudreveApp(),
  ));
}

class CloudreveApp extends ConsumerWidget {
  const CloudreveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final config = ref.watch(siteConfigProvider).valueOrNull;
    final locale = settings.language.locale ??
        AppLocalizations.resolveLocale(
          WidgetsBinding.instance.platformDispatcher.locale,
        );
    // 供没有 BuildContext 的代码取当前语言文案。
    appL10n = AppLocalizations(locale);

    return MaterialApp(
      // 语言切换时整体重建一次，保证所有页面立即换成新语言。
      key: ValueKey('app-${locale.languageCode}'),
      title: config?.title ?? 'Cloudreve',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(config),
      darkTheme: AppTheme.dark(config),
      themeMode: themeModeFromString(settings.themeMode),
      // 界面语言：跟随系统 / 简体中文 / English。
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // 系统语言不是中文时统一回退英文。
      localeResolutionCallback: (locale, supported) =>
          AppLocalizations.resolveLocale(locale),
      home: const UpdateDownloadWatcher(child: RootPage()),
    );
  }
}
