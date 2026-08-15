import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_events.dart';
import '../providers/auth_provider.dart';
import '../providers/sites_provider.dart';
import 'downloads_page.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'site_edit_page.dart';

/// 根页面：根据「是否配置站点 / 是否已登录」决定展示哪个页面。
///
/// 同时监听应用级原生事件（目前是通知栏点击打开下载页）。
class RootPage extends ConsumerStatefulWidget {
  const RootPage({super.key});

  @override
  ConsumerState<RootPage> createState() => _RootPageState();
}

class _RootPageState extends ConsumerState<RootPage> {
  @override
  void initState() {
    super.initState();
    AppEventBus.addListener(_onAppEvent);
    // 冷启动：点击通知打开 App 时，直接跳转下载页。
    if (AppEventBus.consumePendingOpenDownloads()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openDownloads();
      });
    }
  }

  @override
  void dispose() {
    AppEventBus.removeListener(_onAppEvent);
    super.dispose();
  }

  void _onAppEvent(String event) {
    if (event == 'open_downloads' && mounted) {
      _openDownloads();
    }
  }

  void _openDownloads() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DownloadsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sites = ref.watch(sitesProvider);
    final auth = ref.watch(authProvider);

    if (sites.isEmpty) {
      return const _NoSitesPage();
    }
    if (auth.loading) {
      return const _Splash();
    }
    if (auth.isLoggedIn) {
      return const HomePage();
    }
    return const LoginPage();
  }
}

class _NoSitesPage extends StatelessWidget {
  const _NoSitesPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cloudreve')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 64),
            const SizedBox(height: 16),
            const Text('还没有配置任何站点'),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('添加站点'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SiteEditPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
