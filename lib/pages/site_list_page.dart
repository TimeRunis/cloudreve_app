import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/site.dart';
import '../providers/settings_provider.dart';
import '../providers/sites_provider.dart';
import '../widgets/common/empty_view.dart';
import 'site_edit_page.dart';
import '../core/i18n/app_localizations.dart';

/// 站点管理 / 切换页。
class SiteListPage extends ConsumerWidget {
  const SiteListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sites = ref.watch(sitesProvider);
    final currentId = ref.watch(settingsProvider).currentSiteId;

    return Scaffold(
      appBar: AppBar(title: Text(tr('站点'))),
      body: sites.isEmpty
          ? EmptyView(
              icon: Icons.cloud_off_outlined,
              iconSize: 64,
              title: tr('还没有配置任何站点'),
              actionLabel: tr('添加站点'),
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SiteEditPage()),
              ),
            )
          : ListView.separated(
              itemCount: sites.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final site = sites[i];
                final isCurrent = site.id == currentId;
                return ListTile(
                  leading: Icon(
                    Icons.dns_outlined,
                    color: isCurrent
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(site.name),
                  subtitle: Text(site.normalizedBaseUrl),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isCurrent) const Icon(Icons.check_circle),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _edit(context, site),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(context, ref, site),
                      ),
                    ],
                  ),
                  onTap: () => _select(context, ref, site),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _add(context),
      ),
    );
  }

  Future<void> _select(BuildContext context, WidgetRef ref, Site site) async {
    await ref.read(settingsProvider.notifier).setCurrentSite(site.id);
    if (context.mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  void _add(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SiteEditPage()),
    );
  }

  void _edit(BuildContext context, Site site) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SiteEditPage(site: site)),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Site site) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('删除站点')),
        content:
            Text(tr('确定删除站点「{name}」及其本地登录状态吗？', args: {'name': site.name})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('删除')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(sitesProvider.notifier).removeSite(site.id);
    }
  }
}
