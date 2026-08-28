import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../models/file_item.dart';
import '../providers/directory_provider.dart';
import '../providers/settings_provider.dart';
import 'file_icon.dart';

/// 悬浮侧边栏面板（独立组件）。
///
/// 「我的文件」与「与我共享」为可折叠分组；「我的文件」下的子项来自 API
/// 返回的目录结构。
class SidebarPanel extends ConsumerStatefulWidget {
  final String title;
  final ValueChanged<String> onNavigate;
  final VoidCallback onPlaceholder;
  final VoidCallback onCycleTheme;
  final VoidCallback onManageSites;
  final VoidCallback? onDownloads;
  final VoidCallback? onTrash;
  final ValueChanged<FileCategory>? onCategory;
  final VoidCallback? onMyShares;

  const SidebarPanel({
    super.key,
    required this.title,
    required this.onNavigate,
    required this.onPlaceholder,
    required this.onCycleTheme,
    required this.onManageSites,
    this.onDownloads,
    this.onTrash,
    this.onCategory,
    this.onMyShares,
  });

  @override
  ConsumerState<SidebarPanel> createState() => _SidebarPanelState();
}

class _SidebarPanelState extends ConsumerState<SidebarPanel> {
  bool _myFilesExpanded = true;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screen = media.size;
    final maxHeight = screen.height - media.padding.top - media.padding.bottom - 32;

    return SizedBox(
      width: screen.width * 0.75,
      child: Material(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(16),
        elevation: 8,
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SidebarHeader(title: widget.title),
              Flexible(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(children: _buildMenu()),
                  ),
                ),
              ),
              const _SidebarStorage(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMenu() {
    final folders = _rootFolders();
    return [
      _GroupHeader(
        icon: Icons.home_outlined,
        label: '我的文件',
        expanded: _myFilesExpanded,
        active: true,
        onTap: () => setState(() => _myFilesExpanded = !_myFilesExpanded),
      ),
      if (_myFilesExpanded)
        ...folders.map((f) => _FolderNode(
              folder: f,
              depth: 1,
              onNavigate: widget.onNavigate,
            )),
      _SidebarItem(
          icon: Icons.image_outlined,
          label: '图片',
          onTap: () => widget.onCategory == null
              ? widget.onPlaceholder()
              : widget.onCategory!(FileCategory.image)),
      _SidebarItem(
          icon: Icons.videocam_outlined,
          label: '视频',
          onTap: () => widget.onCategory == null
              ? widget.onPlaceholder()
              : widget.onCategory!(FileCategory.video)),
      _SidebarItem(
          icon: Icons.music_note_outlined,
          label: '音乐',
          onTap: () => widget.onCategory == null
              ? widget.onPlaceholder()
              : widget.onCategory!(FileCategory.music)),
      _SidebarItem(
          icon: Icons.description_outlined,
          label: '文档',
          onTap: () => widget.onCategory == null
              ? widget.onPlaceholder()
              : widget.onCategory!(FileCategory.doc)),
      _SidebarItem(
          icon: Icons.delete_outline,
          label: '回收站',
          onTap: widget.onTrash ?? widget.onPlaceholder),
      _SidebarItem(
          icon: Icons.share_outlined,
          label: '我的分享',
          onTap: widget.onMyShares ?? widget.onPlaceholder),
      _SidebarItem(
          icon: Icons.download_outlined,
          label: '下载任务',
          onTap: widget.onDownloads ?? widget.onPlaceholder),
      Divider(height: 1, color: context.appColors.border),
      _SidebarItem(
          icon: Icons.brightness_6_outlined,
          label: '主题（${_themeLabel(ref.watch(settingsProvider).themeMode)}）',
          onTap: widget.onCycleTheme),
      _SidebarItem(
          icon: Icons.dns_outlined,
          label: '管理站点',
          onTap: widget.onManageSites),
    ];
  }

  String _themeLabel(String mode) {
    switch (mode) {
      case 'light':
        return '亮色';
      case 'dark':
        return '暗色';
      default:
        return '跟随系统';
    }
  }

  List<FileItem> _rootFolders() {
    final listing = ref.watch(directoryProvider('/')).valueOrNull;
    if (listing == null) return const [];
    return listing.files.where((f) => f.isFolder).toList();
  }
}

class _SidebarHeader extends StatelessWidget {
  final String title;

  const _SidebarHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF33B5E5), Color(0xFF0086C9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cloud, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.appColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 可折叠分组头（我的文件 / 与我共享）。
class _GroupHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool expanded;
  final bool active;
  final VoidCallback onTap;

  const _GroupHeader({
    required this.icon,
    required this.label,
    required this.expanded,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? scheme.primaryContainer : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              expanded ? Icons.keyboard_arrow_down : Icons.chevron_right,
              size: 18,
              color: active ? scheme.primary : context.appColors.textMuted,
            ),
            const SizedBox(width: 4),
            Icon(icon,
                size: 16,
                color: active
                    ? scheme.primary
                    : context.appColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: active
                      ? scheme.primary
                      : context.appColors.textSecondary,
                  fontWeight: active ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Icon(icon, size: 16, color: context.appColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 14, color: context.appColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 多级目录树节点。
class _FolderNode extends ConsumerStatefulWidget {
  final FileItem folder;
  final int depth;
  final ValueChanged<String> onNavigate;

  const _FolderNode({
    required this.folder,
    required this.depth,
    required this.onNavigate,
  });

  @override
  ConsumerState<_FolderNode> createState() => _FolderNodeState();
}

class _FolderNodeState extends ConsumerState<_FolderNode> {
  bool _expanded = false;

  List<FileItem> _subfolders() {
    final listing =
        ref.watch(directoryProvider(widget.folder.relativePath)).valueOrNull;
    if (listing == null) return const [];
    return listing.files.where((f) => f.isFolder).toList();
  }

  @override
  Widget build(BuildContext context) {
    final subfolders = _expanded ? _subfolders() : const <FileItem>[];
    final indent = widget.depth * 14;

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.only(
              left: 12.0 + indent,
              right: 12,
              top: 8,
              bottom: 8,
            ),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.keyboard_arrow_down : Icons.chevron_right,
                  size: 18,
                  color: context.appColors.textMuted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: InkWell(
                    onTap: () => widget.onNavigate(widget.folder.relativePath),
                    child: Row(
                      children: [
                        Icon(Icons.folder_outlined,
                            size: 16,
                            color: context.appColors.textSecondary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.folder.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14,
                                color: context.appColors.textSecondary),
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
        if (_expanded)
          ...subfolders.map((f) => _FolderNode(
                folder: f,
                depth: widget.depth + 1,
                onNavigate: widget.onNavigate,
              )),
      ],
    );
  }
}

class _SidebarStorage extends ConsumerWidget {
  const _SidebarStorage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capacity = ref.watch(capacityProvider).valueOrNull;
    final used = capacity?.used ?? 0;
    final total = capacity?.total ?? 0;
    final percent = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    final usedText = used > 0 ? formatSize(used) : '--';
    final totalText = total > 0 ? formatSize(total) : '--';

    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: context.appColors.toolbarBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('存储空间',
                style: TextStyle(
                    fontSize: 14, color: context.appColors.textPrimary)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent,
                minHeight: 4,
                backgroundColor: context.appColors.surfaceMuted,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text('$usedText / $totalText',
                style: TextStyle(
                    fontSize: 12, color: context.appColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
