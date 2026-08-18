import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_events.dart';
import '../core/network/cloudreve_api.dart';
import '../providers/auth_provider.dart';
import '../providers/sites_provider.dart';
import 'downloads_page.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'share_viewer_page.dart';
import 'site_edit_page.dart';

/// 根页面：根据「是否配置站点 / 是否已登录」决定展示哪个页面。
///
/// 同时监听应用级原生事件（目前是通知栏点击打开下载页）。
class RootPage extends ConsumerStatefulWidget {
  const RootPage({super.key});

  @override
  ConsumerState<RootPage> createState() => _RootPageState();
}

class _RootPageState extends ConsumerState<RootPage>
    with WidgetsBindingObserver {
  /// 上一次已处理过的分享链接，避免每次回到前台重复弹出。
  String? _lastHandledShareUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppEventBus.addListener(_onAppEvent);
    // 冷启动：点击通知打开 App 时，直接跳转下载页。
    if (AppEventBus.consumePendingOpenDownloads()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openDownloads();
      });
    }
    // 首次启动也检查剪贴板，如果能解析出已管理站点的分享链接则打开展示。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _handleClipboardShareLink();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppEventBus.removeListener(_onAppEvent);
    super.dispose();
  }

  /// App 回到前台时读取剪贴板，检测已管理站点的分享链接并打开。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _handleClipboardShareLink();
    }
  }

  Future<void> _handleClipboardShareLink() async {
    final sites = ref.read(sitesProvider);
    if (sites.isEmpty) return;
    String text;
    try {
      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      text = clip?.text?.trim() ?? '';
    } catch (e) {
      print('[RootPage] 读取剪贴板失败: $e');
      return;
    }
    if (text.isEmpty) return;
    if (text == _lastHandledShareUrl) return;

    for (final site in sites) {
      final parsed = parseShareLinkFromText(text, site.baseUrl);
      if (parsed == null) continue;
      _lastHandledShareUrl = text;
      if (!mounted) return;

      // 尽量获取分享链接用户名；失败时回退显示站点名。
      var ownerLabel = site.name;
      final shareApi = CloudreveApi(dio: createDio(), site: site);
      try {
        final info = await shareApi.getShareInfo(
          parsed.shareId,
          password: parsed.password,
        );
        ownerLabel = info.ownerNickname ?? info.ownerEmail ?? site.name;
      } catch (e) {
        print('[RootPage] 获取分享用户信息失败: $e');
      } finally {
        shareApi.dio.close(force: true);
      }
      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('打开分享链接'),
          content: Text('检测到来自「$ownerLabel」的分享链接，是否打开？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('打开'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ShareViewerPage(
            site: site,
            shareId: parsed.shareId,
            password: parsed.password,
          ),
        ),
      );
      return;
    }
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
