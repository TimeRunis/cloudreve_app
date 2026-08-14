import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/sites_provider.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'site_edit_page.dart';

/// 根页面：根据「是否配置站点 / 是否已登录」决定展示哪个页面。
class RootPage extends ConsumerWidget {
  const RootPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
