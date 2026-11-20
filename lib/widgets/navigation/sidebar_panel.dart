import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_mode_label.dart';
import '../../models/file_item.dart';
import '../../providers/directory_provider.dart';
import '../../providers/settings_provider.dart';
import '../common/site_logo.dart';
import '../file/file_icon.dart';
import '../file/file_item_icon.dart';

/// 悬浮侧边栏面板（独立组件）。
///
/// 「我的文件」与「与我共享」为可折叠分组；「我的文件」下的子项来自 API
/// 返回的目录结构。
class SidebarPanel extends ConsumerStatefulWidget {
  final ValueChanged<FileItem> onNavigate;
  final VoidCallback onPlaceholder;
  final VoidCallback onCycleTheme;
  final VoidCallback? onDownloads;
  final VoidCallback? onTrash;
  final ValueChanged<FileCategory>? onCategory;
  final VoidCallback? onMyShares;
  final VoidCallback? onSharedWithMe;

  /// 「与我共享」是否为当前主页视图（高亮分组标题）。
  final bool sharedWithMeActive;
  final VoidCallback? onSettings;

  const SidebarPanel({
    super.key,
    required this.onNavigate,
    required this.onPlaceholder,
    required this.onCycleTheme,
    this.onDownloads,
    this.onTrash,
    this.onCategory,
    this.onMyShares,
    this.onSharedWithMe,
    this.sharedWithMeActive = false,
    this.onSettings,
  });

  @override
  ConsumerState<SidebarPanel> createState() => _SidebarPanelState();
}

class _SidebarPanelState extends ConsumerState<SidebarPanel> {
  /// 宽屏 / 超宽屏断点，与文件网格保持一致。
  static const double _wideBreakpoint = 600;
  static const double _ultraWideBreakpoint = 1000;

  /// 侧边栏宽度占屏幕宽度的比例：窄屏 75%、宽屏 40%、超宽屏 30%。
  static double _widthRatio(double screenWidth) {
    if (screenWidth >= _ultraWideBreakpoint) return 0.30;
    if (screenWidth >= _wideBreakpoint) return 0.40;
    return 0.75;
  }

  bool _myFilesExpanded = true;

  /// 「与我共享」分组是否展开（只列一级分享快捷方式，不展开分享内部目录）。
  bool _sharedExpanded = false;

  @override
  void initState() {
    super.initState();
    _sharedExpanded = widget.sharedWithMeActive;
  }

  @override
  void didUpdateWidget(covariant SidebarPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sharedWithMeActive && !oldWidget.sharedWithMeActive) {
      _sharedExpanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screen = media.size;
    final maxHeight =
        screen.height - media.padding.top - media.padding.bottom - 32;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SizedBox(
        // 宽度分三档：窄屏 75%、宽屏 50%、超宽屏 30%。
        width: screen.width * _widthRatio(screen.width),
        child: Material(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(16),
          elevation: 8,
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SidebarHeader(),
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
    final l10n = AppLocalizations.of(context);
    return [
      _GroupHeader(
        icon: Icons.home_outlined,
        label: l10n.t('我的文件'),
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
          label: l10n.t('图片'),
          onTap: () => widget.onCategory == null
              ? widget.onPlaceholder()
              : widget.onCategory!(FileCategory.image)),
      _SidebarItem(
          icon: Icons.videocam_outlined,
          label: l10n.t('视频'),
          onTap: () => widget.onCategory == null
              ? widget.onPlaceholder()
              : widget.onCategory!(FileCategory.video)),
      _SidebarItem(
          icon: Icons.music_note_outlined,
          label: l10n.t('音乐'),
          onTap: () => widget.onCategory == null
              ? widget.onPlaceholder()
              : widget.onCategory!(FileCategory.music)),
      _SidebarItem(
          icon: Icons.description_outlined,
          label: l10n.t('文档'),
          onTap: () => widget.onCategory == null
              ? widget.onPlaceholder()
              : widget.onCategory!(FileCategory.doc)),
      _GroupHeader(
        icon: Icons.people_outline,
        label: l10n.t('与我共享'),
        expanded: _sharedExpanded,
        active: widget.sharedWithMeActive,
        onTap: () {
          if (!_sharedExpanded) setState(() => _sharedExpanded = true);
          (widget.onSharedWithMe ?? widget.onPlaceholder)();
        },
        onToggle: () => setState(() => _sharedExpanded = !_sharedExpanded),
      ),
      // 只列出一级分享快捷方式，不展示分享内部的目录层级。
      if (_sharedExpanded)
        ..._sharedFiles().map((file) => _SharedNode(
              file: file,
              onTap: () => widget.onNavigate(file),
            )),
      _SidebarItem(
          icon: Icons.delete_outline,
          label: l10n.t('回收站'),
          onTap: widget.onTrash ?? widget.onPlaceholder),
      _SidebarItem(
          icon: Icons.share_outlined,
          label: l10n.t('我的分享'),
          onTap: widget.onMyShares ?? widget.onPlaceholder),
      _SidebarItem(
          icon: Icons.download_outlined,
          label: l10n.t('下载任务'),
          onTap: widget.onDownloads ?? widget.onPlaceholder),
      Divider(height: 1, color: context.appColors.border),
      _SidebarItem(
          icon: Icons.brightness_6_outlined,
          label: l10n.t(
            '主题（{mode}）',
            args: {
              'mode': themeModeLabel(
                ref.watch(settingsProvider).themeMode,
                l10n,
              ),
            },
          ),
          onTap: widget.onCycleTheme),
      _SidebarItem(
          icon: Icons.settings_outlined,
          label: l10n.t('设置'),
          onTap: widget.onSettings ?? widget.onPlaceholder),
    ];
  }

  List<FileItem> _rootFolders() {
    final listing =
        ref.watch(directoryProvider(const DirectoryQuery('/'))).valueOrNull;
    if (listing == null) return const [];
    return listing.files.where((f) => f.isFolder).toList();
  }

  /// 「与我共享」下的分享快捷方式（一级）。
  List<FileItem> _sharedFiles() {
    if (!_sharedExpanded) return const [];
    return ref.watch(sharedWithMeProvider).valueOrNull ?? const [];
  }
}

/// 侧边栏头部：只显示站点 logo（站点名不再展示）。
class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SiteLogo(
          height: 32,
          maxWidth: 160,
          fallback: const _FallbackLogo(),
        ),
      ),
    );
  }
}

/// 站点未配置 logo（或加载失败）时的默认图标。
class _FallbackLogo extends StatelessWidget {
  const _FallbackLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

/// 可折叠分组头（我的文件 / 与我共享）。
///
/// 主体（图标 + 文字）点击交给 [onTap]；左侧箭头单独响应 [onToggle]，
/// 这样「与我共享」可以点主体切换视图、点箭头只展开 / 收起。
class _GroupHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool expanded;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onToggle;

  const _GroupHeader({
    required this.icon,
    required this.label,
    required this.expanded,
    required this.onTap,
    this.onToggle,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final arrowColor = active ? scheme.primary : context.appColors.textMuted;
    return Material(
      color: active ? scheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          InkWell(
            onTap: onToggle ?? onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Icon(
                expanded ? Icons.keyboard_arrow_down : Icons.chevron_right,
                size: 18,
                color: arrowColor,
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                child: Row(
                  children: [
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
                          fontWeight:
                              active ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 「与我共享」下的一级分享快捷方式：只有名称，不展开分享内部目录。
class _SharedNode extends StatelessWidget {
  final FileItem file;
  final VoidCallback onTap;

  const _SharedNode({required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(48, 8, 12, 8),
        child: Row(
          children: [
            FileItemIcon(
              file: file,
              size: 16,
              color: context.appColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                file.name,
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
  final ValueChanged<FileItem> onNavigate;

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
    final listing = ref
        .watch(directoryProvider(DirectoryQuery(widget.folder.relativePath)))
        .valueOrNull;
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
                    onTap: () => widget.onNavigate(widget.folder),
                    child: Row(
                      children: [
                        FileItemIcon(
                          file: widget.folder,
                          size: 16,
                          color: context.appColors.textSecondary,
                        ),
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
    final l10n = AppLocalizations.of(context);
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
            Text(l10n.t('存储空间'),
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
