import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format/date_time.dart';
import '../core/i18n/app_localizations.dart';
import '../core/theme/app_colors.dart';
import '../models/share_history.dart';
import '../providers/share_history_provider.dart';
import '../widgets/common/confirm_dialog.dart';
import '../widgets/common/empty_view.dart';
import 'share_viewer_page.dart';

/// 本地分享打开历史：支持单条 / 多条选择删除，以及一键清空。
class ShareHistoryPage extends ConsumerStatefulWidget {
  const ShareHistoryPage({super.key});

  @override
  ConsumerState<ShareHistoryPage> createState() => _ShareHistoryPageState();
}

class _ShareHistoryPageState extends ConsumerState<ShareHistoryPage> {
  bool _selectionMode = false;
  final Set<String> _selected = {};

  void _enterSelection([ShareHistoryEntry? entry]) {
    setState(() {
      _selectionMode = true;
      if (entry != null) _selected.add(entry.id);
    });
  }

  void _exitSelection() {
    if (!_selectionMode && _selected.isEmpty) return;
    setState(() {
      _selectionMode = false;
      _selected.clear();
    });
  }

  void _toggle(ShareHistoryEntry entry) {
    setState(() {
      if (!_selected.add(entry.id)) {
        _selected.remove(entry.id);
      }
    });
  }

  void _toggleSelectAll(List<ShareHistoryEntry> entries) {
    setState(() {
      if (_selected.length == entries.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(entries.map((e) => e.id));
      }
    });
  }

  void _open(ShareHistoryEntry entry) {
    if (_selectionMode) {
      _toggle(entry);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShareViewerPage(
          site: entry.site,
          shareId: entry.shareId,
          password: entry.password,
        ),
      ),
    );
  }

  Future<void> _deleteSelected() async {
    final ids = Set<String>.of(_selected);
    if (ids.isEmpty) return;
    final confirmed = await showConfirmDialog(
      context,
      title: tr('删除分享历史'),
      message: tr(
        '确定删除选中的 {count} 条分享历史吗？',
        args: {'count': ids.length},
      ),
      actionLabel: tr('删除'),
      danger: true,
    );
    if (!confirmed || !mounted) return;
    await ref.read(shareHistoryProvider.notifier).remove(ids);
    if (!mounted) return;
    _exitSelection();
    _toast(tr('已删除'));
  }

  Future<void> _clearAll() async {
    final confirmed = await showConfirmDialog(
      context,
      title: tr('清空分享历史'),
      message: tr('确定清空全部分享历史吗？'),
      actionLabel: tr('清空'),
      danger: true,
    );
    if (!confirmed || !mounted) return;
    await ref.read(shareHistoryProvider.notifier).clear();
    if (!mounted) return;
    _exitSelection();
    _toast(tr('已清空'));
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(shareHistoryProvider);
    final colors = context.appColors;
    final selecting = _selectionMode;
    final allSelected =
        entries.isNotEmpty && _selected.length == entries.length;

    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _exitSelection();
      },
      child: Scaffold(
        backgroundColor: colors.contentBg,
        appBar: AppBar(
          backgroundColor: colors.headerBg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            tooltip: selecting ? tr('取消选择') : tr('关闭'),
            icon: Icon(Icons.close, size: 18, color: colors.textSecondary),
            onPressed:
                selecting ? _exitSelection : () => Navigator.of(context).pop(),
          ),
          title: Text(
            selecting
                ? tr('已选 {count} 项', args: {'count': _selected.length})
                : tr('分享历史'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colors.textPrimary,
            ),
          ),
          actions: selecting
              ? [
                  IconButton(
                    tooltip: allSelected ? tr('取消全选') : tr('全选'),
                    icon: Icon(
                      allSelected ? Icons.deselect : Icons.select_all,
                      size: 20,
                      color: colors.textSecondary,
                    ),
                    onPressed: entries.isEmpty
                        ? null
                        : () => _toggleSelectAll(entries),
                  ),
                  IconButton(
                    tooltip: tr('删除选中'),
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: _selected.isEmpty
                          ? colors.textMuted
                          : colors.textSecondary,
                    ),
                    onPressed: _selected.isEmpty ? null : _deleteSelected,
                  ),
                  const SizedBox(width: 8),
                ]
              : [
                  IconButton(
                    tooltip: tr('选择'),
                    icon: Icon(
                      Icons.checklist,
                      size: 20,
                      color: colors.textSecondary,
                    ),
                    onPressed: entries.isEmpty ? null : () => _enterSelection(),
                  ),
                  IconButton(
                    tooltip: tr('清空分享历史'),
                    icon: Icon(
                      Icons.delete_sweep_outlined,
                      size: 20,
                      color: colors.textSecondary,
                    ),
                    onPressed: entries.isEmpty ? null : _clearAll,
                  ),
                  const SizedBox(width: 8),
                ],
        ),
        body: entries.isEmpty
            ? EmptyView(
                icon: Icons.history,
                iconSize: 48,
                title: tr('还没有分享历史'),
                subtitle: tr('在搜索栏粘贴分享链接并搜索后，会自动记录到这里'),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return _HistoryCard(
                    entry: entry,
                    selectionMode: selecting,
                    selected: _selected.contains(entry.id),
                    onTap: () => _open(entry),
                    onLongPress:
                        selecting ? null : () => _enterSelection(entry),
                  );
                },
              ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final ShareHistoryEntry entry;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _HistoryCard({
    required this.entry,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  String get _meta {
    final owner = entry.owner?.trim() ?? '';
    return owner.isEmpty ? entry.site.name : '$owner · ${entry.site.name}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: selected ? scheme.primaryContainer : colors.surface,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? scheme.primary : colors.border,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              if (selectionMode)
                IgnorePointer(
                  child: Checkbox(
                    value: selected,
                    onChanged: (_) {},
                    visualDensity: VisualDensity.compact,
                  ),
                )
              else
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.share_outlined,
                    size: 18,
                    color: scheme.primary,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatDateTime(entry.openedAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.displayUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
              if (!selectionMode) ...[
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, size: 18, color: colors.textMuted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
