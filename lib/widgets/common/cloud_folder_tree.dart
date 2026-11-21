import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../models/file_item.dart';
import '../file/file_item_icon.dart';

/// 文件夹树中一行的类型。
enum CloudFolderTreeEntryKind { folder, loading, error, empty }

/// 文件夹树中的一行。
///
/// 只描述渲染所需的数据，不包含任何加载 / 请求逻辑。调用方自行加载目录，
/// 再把当前可见的节点展开成 [CloudFolderTreeEntry] 列表交给 [CloudFolderTree]。
class CloudFolderTreeEntry {
  /// 稳定标识，通常为文件夹 path；根节点由调用方指定。
  final String id;

  final String label;
  final int depth;
  final CloudFolderTreeEntryKind kind;

  /// 是否为树的根节点（使用 home 图标）。
  final bool isRoot;

  /// 是否已展开；仅 [CloudFolderTreeEntryKind.folder] 有效。
  final bool expanded;

  /// 是否为当前选中项；仅 [CloudFolderTreeEntryKind.folder] 有效。
  final bool selected;

  /// 文件夹对象；根节点为 null。
  final FileItem? folder;

  const CloudFolderTreeEntry.folder({
    required this.id,
    required this.label,
    required this.depth,
    this.isRoot = false,
    this.expanded = false,
    this.selected = false,
    this.folder,
  }) : kind = CloudFolderTreeEntryKind.folder;

  const CloudFolderTreeEntry.loading({
    required this.id,
    required this.depth,
  })  : label = '',
        kind = CloudFolderTreeEntryKind.loading,
        isRoot = false,
        expanded = false,
        selected = false,
        folder = null;

  const CloudFolderTreeEntry.error({
    required this.id,
    required this.depth,
  })  : label = '',
        kind = CloudFolderTreeEntryKind.error,
        isRoot = false,
        expanded = false,
        selected = false,
        folder = null;

  const CloudFolderTreeEntry.empty({
    required this.id,
    required this.depth,
  })  : label = '',
        kind = CloudFolderTreeEntryKind.empty,
        isRoot = false,
        expanded = false,
        selected = false,
        folder = null;
}

/// 通用云端文件夹树（纯展示组件）。
///
/// 不持有 API、不发起请求、不管理展开状态；数据、展开态、选中态都由调用方
/// 通过 [entries] 和回调控制。视觉样式与悬浮侧边栏的目录树一致。
class CloudFolderTree extends StatelessWidget {
  /// 当前可见的树节点，按显示顺序排列。
  final List<CloudFolderTreeEntry> entries;

  /// 点击文件夹主体。
  final ValueChanged<CloudFolderTreeEntry> onSelect;

  /// 点击展开箭头。
  final ValueChanged<CloudFolderTreeEntry> onToggle;

  /// 加载失败时的重试回调；为空时不显示重试按钮。
  final ValueChanged<CloudFolderTreeEntry>? onRetry;

  /// 树内容边距，默认给选中高亮留出足够的四周空间。
  final EdgeInsetsGeometry padding;

  /// 紧凑模式：行高和留白与悬浮侧边栏保持一致。
  final bool dense;

  /// 是否自带滚动。嵌入到已有滚动容器时传 false，组件会渲染为 Column。
  final bool scrollable;

  const CloudFolderTree({
    super.key,
    required this.entries,
    required this.onSelect,
    required this.onToggle,
    this.onRetry,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 24),
    this.dense = false,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      for (final entry in entries) _buildEntry(entry),
    ];
    if (!scrollable) {
      return Padding(
        padding: padding,
        child: Column(children: rows),
      );
    }
    return ListView(padding: padding, children: rows);
  }

  Widget _buildEntry(CloudFolderTreeEntry entry) {
    switch (entry.kind) {
      case CloudFolderTreeEntryKind.folder:
        return _FolderRow(
          key: ValueKey('folder-tree-row-${entry.id}'),
          label: entry.label,
          file: entry.folder,
          icon: entry.isRoot ? Icons.home_outlined : null,
          depth: entry.depth,
          selected: entry.selected,
          expanded: entry.expanded,
          dense: dense,
          expandKey: ValueKey('folder-tree-expand-${entry.id}'),
          onTap: () => onSelect(entry),
          onToggle: () => onToggle(entry),
        );
      case CloudFolderTreeEntryKind.loading:
        return _TreeLoading(depth: entry.depth, dense: dense);
      case CloudFolderTreeEntryKind.error:
        return _TreeError(
          depth: entry.depth,
          dense: dense,
          onRetry: onRetry == null ? null : () => onRetry!(entry),
        );
      case CloudFolderTreeEntryKind.empty:
        return _TreeEmpty(depth: entry.depth, dense: dense);
    }
  }
}

/// 目录树中的一行：展开箭头、文件夹图标、名称。
///
/// 箭头和主体分为两个独立的点击区域，点主体选中，点箭头展开 / 收起。
class _FolderRow extends StatelessWidget {
  final String label;

  /// 根目录使用 home 图标；[file] 不为空时使用文件图标（含分享徽标）。
  final IconData? icon;
  final FileItem? file;
  final int depth;
  final bool selected;
  final bool expanded;
  final bool dense;
  final Key? expandKey;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  const _FolderRow({
    super.key,
    required this.label,
    this.icon,
    this.file,
    required this.depth,
    required this.selected,
    required this.expanded,
    required this.dense,
    this.expandKey,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? scheme.primary : colors.textSecondary;
    final iconColor = selected ? scheme.primary : colors.textSecondary;
    final rowHeight = dense ? 36.0 : 46.0;
    final arrowWidth = dense ? 28.0 : 32.0;
    final rightPadding = dense ? 12.0 : 16.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: rowHeight),
            child: Row(
              children: [
                SizedBox(width: _indent(depth)),
                InkResponse(
                  key: expandKey,
                  onTap: onToggle,
                  radius: dense ? 18 : 20,
                  child: SizedBox(
                    width: arrowWidth,
                    height: rowHeight,
                    child: Icon(
                      expanded
                          ? Icons.keyboard_arrow_down
                          : Icons.chevron_right,
                      size: 18,
                      color: selected ? scheme.primary : colors.textMuted,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: rightPadding),
                    child: Row(
                      children: [
                        if (file != null)
                          FileItemIcon(
                            file: file!,
                            size: 16,
                            color: iconColor,
                          )
                        else
                          Icon(
                            icon ?? Icons.folder_rounded,
                            size: 16,
                            color: iconColor,
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: foreground,
                              fontWeight: selected
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TreeLoading extends StatelessWidget {
  final int depth;
  final bool dense;

  const _TreeLoading({required this.depth, required this.dense});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _indent(depth) + (dense ? 56 : 60),
        0,
        dense ? 12 : 16,
        0,
      ),
      child: SizedBox(
        height: dense ? 36 : 44,
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              l10n.t('读取中…'),
              style: TextStyle(fontSize: 13, color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _TreeError extends StatelessWidget {
  final int depth;
  final bool dense;
  final VoidCallback? onRetry;

  const _TreeError({
    required this.depth,
    required this.dense,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _indent(depth) + (dense ? 56 : 60),
        dense ? 2 : 4,
        dense ? 8 : 16,
        dense ? 2 : 4,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: colors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.t('加载文件列表失败'),
              style: TextStyle(fontSize: 13, color: colors.textSecondary),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(l10n.t('重试')),
            ),
        ],
      ),
    );
  }
}

class _TreeEmpty extends StatelessWidget {
  final int depth;
  final bool dense;

  const _TreeEmpty({required this.depth, required this.dense});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _indent(depth) + (dense ? 56 : 60),
        dense ? 6 : 8,
        dense ? 12 : 16,
        dense ? 6 : 8,
      ),
      child: Text(
        l10n.t('没有子文件夹'),
        style: TextStyle(fontSize: 13, color: context.appColors.textMuted),
      ),
    );
  }
}

/// 树节点缩进：与侧边栏目录树一致，每级 14，最多缩进 140。
double _indent(int depth) {
  final value = 12 + depth * 14;
  return value > 140 ? 140 : value.toDouble();
}
