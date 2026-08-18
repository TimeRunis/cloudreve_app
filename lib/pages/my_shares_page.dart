import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../models/share.dart';
import '../providers/api_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/file_icon.dart';
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
      builder: (context) => AlertDialog(
        title: const Text('删除分享'),
        content: Text('确定删除分享「${share.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
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

  void _handleMenu(ShareLink share, String action) {
    switch (action) {
      case 'open':
        _open(share);
        break;
      case 'copy':
        _copy(share);
        break;
      case 'delete':
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
          icon: Icon(Icons.close,
              size: 18, color: colors.textSecondary),
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
            icon: Icon(Icons.refresh,
                size: 20, color: colors.textSecondary),
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
            return Center(
              child: Text(
                '加载失败：${snapshot.error}',
                style: TextStyle(color: colors.textSecondary),
              ),
            );
          }
          final shares = snapshot.data ?? const <ShareLink>[];
          if (shares.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.share_outlined,
                      size: 48, color: colors.textMuted),
                  const SizedBox(height: 8),
                  Text('还没有分享链接',
                      style: TextStyle(
                          fontSize: 14, color: colors.textSecondary)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: shares.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final share = shares[index];
              return _ShareCard(
                share: share,
                onTap: () => _open(share),
                onMenu: (action) => _handleMenu(share, action),
              );
            },
          );
        },
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  final ShareLink share;
  final VoidCallback onTap;
  final ValueChanged<String> onMenu;

  const _ShareCard({
    required this.share,
    required this.onTap,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    share.isFolder
                        ? Icons.folder_outlined
                        : fileIconForName(share.name),
                    size: 22,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (share.isPrivate == true) ...[
                            Icon(Icons.lock_outline,
                                size: 14, color: colors.textMuted),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              share.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          if (share.expired) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: colors.border,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '已失效',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(share.createdAt),
                        style: TextStyle(
                            fontSize: 12, color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (share.visited > 0) ...[
                  Icon(Icons.visibility_outlined,
                      size: 16, color: colors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    '${share.visited}',
                    style: TextStyle(
                        fontSize: 13, color: colors.textSecondary),
                  ),
                ],
                PopupMenuButton<String>(
                  tooltip: '更多操作',
                  color: colors.surface,
                  surfaceTintColor: Colors.transparent,
                  icon: Icon(Icons.more_vert,
                      size: 20, color: colors.textSecondary),
                  onSelected: onMenu,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'open',
                      child: _MenuRow(
                          icon: Icons.open_in_new, label: '打开'),
                    ),
                    const PopupMenuItem(
                      value: 'copy',
                      child: _MenuRow(
                          icon: Icons.copy, label: '复制链接到剪切板'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: _MenuRow(
                          icon: Icons.delete_outline, label: '删除'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String raw) {
    final date = DateTime.tryParse(raw);
    if (date == null) return raw;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}/${two(date.month)}/${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}:${two(date.second)}';
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: [
        Icon(icon, size: 18, color: colors.textSecondary),
        const SizedBox(width: 12),
        Text(label,
            style: TextStyle(fontSize: 14, color: colors.textPrimary)),
      ],
    );
  }
}