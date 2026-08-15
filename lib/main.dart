import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_events.dart';
import 'core/network/tls_override.dart';
import 'core/storage/app_storage.dart';
import 'core/theme/app_theme.dart';
import 'pages/root_page.dart';
import 'providers/settings_provider.dart';
import 'providers/site_config_provider.dart';
import 'providers/storage_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installTlsTrustOverride();
  final storage = await AppStorage.create();
  await AppEventBus.init();
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

    return MaterialApp(
      title: config?.title ?? 'Cloudreve',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(config),
      darkTheme: AppTheme.dark(config),
      themeMode: themeModeFromString(settings.themeMode),
      home: const RootPage(),
    );
  }
}
