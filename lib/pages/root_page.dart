import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_events.dart';
import '../core/i18n/app_localizations.dart';
import '../core/network/cloudreve_api.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/sites_provider.dart';
import '../providers/update_provider.dart';
import '../widgets/common/empty_view.dart';
import '../widgets/update/update_flow.dart';
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
    // 启动时按设置里的频率检查更新（默认每次启动都检查）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeCheckUpdate();
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
      // 「每天 / 7 天 / 30 天」模式下，回到前台时若已到期也会补一次检查。
      _maybeCheckUpdate();
    }
  }

  /// 按设置里的频率决定是否检查更新。
  Future<void> _maybeCheckUpdate() async {
    final interval = ref.read(settingsProvider).updateCheckInterval;
    final notifier = ref.read(updateProvider.notifier);
    if (!notifier.isDue(interval)) return;
    await UpdateFlow.checkAndPrompt(
      context,
      ref,
      manual: false,
      onOpenDownloads: _openDownloads,
    );
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
        builder: (dialogContext) {
          final l10n = AppLocalizations.of(dialogContext);
          return AlertDialog(
            title: Text(l10n.t('打开分享链接')),
            content: Text(
              l10n.t(
                '检测到来自「{owner}」的分享链接，是否打开？',
                args: {'owner': ownerLabel},
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.t('取消')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(l10n.t('打开')),
              ),
            ],
          );
        },
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
      final l10n = AppLocalizations.of(context);
      return Scaffold(
        appBar: AppBar(title: const Text('Cloudreve')),
        body: EmptyView(
          icon: Icons.cloud_off_outlined,
          iconSize: 64,
          title: l10n.t('还没有配置任何站点'),
          actionLabel: l10n.t('添加站点'),
          onAction: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SiteEditPage()),
          ),
        ),
      );
    }
    if (auth.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (auth.isLoggedIn) {
      return const HomePage();
    }
    return const LoginPage();
  }
}
