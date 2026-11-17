import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../models/share.dart';
import '../providers/api_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/common/empty_view.dart';
import '../widgets/common/error_view.dart';
import '../widgets/share/share_card.dart';
import 'share_viewer_page.dart';

/// “我的分享”页面：查看、复制、打开、删除当前用户的分享链接。
class MySharesPage extends ConsumerStatefulWidget {
  const MySharesPage({super.key});

  @override
  ConsumerState<MySharesPage> createState() => _MySharesPageState();
}

class _MySharesPageState extends ConsumerState<MySharesPage> {
  late Future<List<ShareLink>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = ref.read(apiProvider).listMyShares(pageSize: 100);
  }

  void _reload() {
    setState(_load);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _copy(ShareLink share) async {
    await Clipboard.setData(ClipboardData(text: share.url));
    if (mounted) _toast('链接已复制');
  }

  Future<void> _delete(ShareLink share) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除分享'),
        content: Text('确定删除分享「${share.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(apiProvider).deleteShare(share.id);
      if (!mounted) return;
      _toast('已删除');
      _reload();
    } catch (e) {
      print('[MySharesPage] 删除分享失败: $e');
      if (mounted) _toast('删除失败，请重试');
    }
  }

  void _open(ShareLink share) {
    final site = ref.read(currentSiteProvider);
    if (site == null) {
      _toast('当前没有可用站点');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShareViewerPage(
          site: site,
          shareId: share.id,
          password: share.password,
        ),
      ),
    );
  }

  void _handleMenu(ShareLink share, ShareCardAction action) {
    switch (action) {
      case ShareCardAction.open:
        _open(share);
        break;
      case ShareCardAction.copyLink:
        _copy(share);
        break;
      case ShareCardAction.delete:
        _delete(share);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.contentBg,
      appBar: AppBar(
        backgroundColor: colors.headerBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: '返回',
          icon: Icon(Icons.close, size: 18, color: colors.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '我的分享',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: colors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: Icon(Icons.refresh, size: 20, color: colors.textSecondary),
            onPressed: _reload,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<ShareLink>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorView(message: '加载失败：${snapshot.error}');
          }
          final shares = snapshot.data ?? const <ShareLink>[];
          if (shares.isEmpty) {
            return const EmptyView(
              icon: Icons.share_outlined,
              iconSize: 48,
              title: '还没有分享链接',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: shares.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final share = shares[index];
              return ShareCard(
                share: share,
                onTap: () => _open(share),
                onAction: (action) => _handleMenu(share, action),
              );
            },
          );
        },
      ),
    );
  }
}
