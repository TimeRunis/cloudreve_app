import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../models/file_item.dart';
import '../models/user.dart';
import '../providers/api_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/directory_provider.dart';
import '../providers/download_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/site_config_provider.dart';
import '../widgets/add_menu_popup.dart';
import '../widgets/file_card.dart';
import '../widgets/file_icon.dart';
import '../widgets/file_info_sheet.dart';
import '../widgets/file_operations_popup.dart';
import '../widgets/image_viewer.dart';
import '../widgets/more_menu_popup.dart';
import '../widgets/search_popup.dart';
import '../widgets/sidebar_panel.dart';
import '../widgets/sort_popup.dart';
import '../widgets/user_menu_popup.dart';
import '../widgets/video_player_viewer.dart';
import '../widgets/view_panel.dart';
import 'downloads_page.dart';
import 'site_list_page.dart';

/// 文件浏览主页。
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String _path = '/';
  String _viewMode = 'grid'; // grid | list | gallery
  bool _thumbnails = true;
  int _pageSize = 50;
  String _sortKey = 'created_at-asc';
  final Set<String> _selected = {};
  DateTime? _lastBackPress;

  void _enter(FileItem folder) {
    setState(() {
      _path = folder.relativePath;
      _selected.clear();
    });
  }

  void _navigateTo(String path) {
    setState(() {
      _path = path;
      _selected.clear();
    });
  }

  /// 计算上一级目录路径。
  String _parentPath(String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return '/';
    segments.removeLast();
    return segments.isEmpty ? '/' : '/${segments.join('/')}';
  }

  /// 系统返回键：非根目录返回上一级，根目录两次返回退出。
  void _handleBackPress() {
    if (_path != '/') {
      _navigateTo(_parentPath(_path));
      return;
    }
    final now = DateTime.now();
    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      _toast('再按一次返回键退出软件');
    } else {
      SystemNavigator.pop();
    }
  }

  void _refresh() {
    ref.invalidate(directoryProvider(_path));
  }

  void _toggleSelect(FileItem file) {
    setState(() {
      if (!_selected.remove(file.path)) {
        _selected.add(file.path);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selected.clear());
  }

  void _open(FileItem file) {
    if (file.isFolder) {
      _enter(file);
    } else if (isImage(file)) {
      _openImageViewer(file);
    } else if (isVideo(file)) {
      _openVideoPlayer(file);
    } else {
      showModalBottomSheet(
        context: context,
        builder: (context) => FileInfoSheet(file: file),
      );
    }
  }

  void _openVideoPlayer(FileItem file) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerViewer(file: file),
      ),
    );
  }

  void _openImageViewer(FileItem file) {
    final listing = ref.read(directoryProvider(_path)).valueOrNull;
    final found =
        (listing?.files ?? const <FileItem>[]).where(isImage).toList();
    final images = found.isEmpty ? [file] : found;
    final index = images.indexWhere((f) => f.path == file.path);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImageViewer(
          images: images,
          initialIndex: index < 0 ? 0 : index,
        ),
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _cycleTheme() {
    final current = ref.read(settingsProvider).themeMode;
    final next = current == 'system'
        ? 'light'
        : current == 'light'
            ? 'dark'
            : 'system';
    ref.read(settingsProvider.notifier).setThemeMode(next);
  }

  void _openSidebar() {
    final title = ref.read(siteConfigProvider).valueOrNull?.title ?? 'Cloudreve';
    final topPad = MediaQuery.of(context).padding.top;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'sidebar',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offset = Tween<Offset>(
          begin: const Offset(-0.2, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
        return SlideTransition(position: offset, child: child);
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              top: topPad + 16,
              left: 16,
              child: SidebarPanel(
                title: title,
                onNavigate: (path) {
                  Navigator.of(context).pop();
                  _navigateTo(path);
                },
                onPlaceholder: () {
                  Navigator.of(context).pop();
                  _toast('功能暂未实现');
                },
                onCycleTheme: _cycleTheme,
                onManageSites: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SiteListPage()),
                  );
                },
                onDownloads: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DownloadsPage()),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _openDownloads() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DownloadsPage()),
    );
  }

  void _openUserMenu() {
    final user = ref.read(authProvider).user;
    final topPad = MediaQuery.of(context).padding.top;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'user-menu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              top: topPad + kToolbarHeight + 8,
              right: 16,
              child: UserMenuPopup(
                user: user,
                onAction: (action) {
                  Navigator.of(context).pop();
                  switch (action) {
                    case UserMenuAction.logout:
                      final s = ref.read(currentSiteProvider);
                      if (s != null) {
                        ref.read(authProvider.notifier).signOut(s);
                      }
                      break;
                    case UserMenuAction.managePanel:
                    case UserMenuAction.settings:
                    case UserMenuAction.profile:
                      _toast('功能暂未实现');
                      break;
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _openAddMenu() {
    final topPad = MediaQuery.of(context).padding.top;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'add-menu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              top: topPad + kToolbarHeight + 8,
              right: 56,
              child: AddMenuPopup(
                onAction: (action) {
                  Navigator.of(context).pop();
                  _toast('功能暂未实现：$action');
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _openSearch() {
    final topPad = MediaQuery.of(context).padding.top;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'search',
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned(
              top: topPad + 12,
              left: 12,
              right: 12,
              child: SearchPopup(
                onSubmitted: (query) {
                  Navigator.of(context).pop();
                  _toast('搜索功能暂未实现：$query');
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _openViewPanel() {
    final topPad = MediaQuery.of(context).padding.top;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'view-panel',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              top: topPad + kToolbarHeight + 40,
              right: 16,
              child: ViewPanel(
                initialViewMode: _viewMode,
                initialThumbnails: _thumbnails,
                initialPageSize: _pageSize,
                onViewModeChanged: (v) => setState(() => _viewMode = v),
                onThumbnailsChanged: (v) => setState(() => _thumbnails = v),
                onPageSizeChanged: (v) => setState(() => _pageSize = v),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openSortMenu() {
    final topPad = MediaQuery.of(context).padding.top;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'sort-menu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              top: topPad + kToolbarHeight + 40,
              right: 64,
              child: SortPopup(
                selected: _sortKey,
                onSelected: (key) {
                  Navigator.of(context).pop();
                  setState(() => _sortKey = key);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _openBreadcrumbPopup() {
    final topPad = MediaQuery.of(context).padding.top;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'breadcrumb',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              top: topPad + kToolbarHeight + 40,
              left: 16,
              child: FileOperationsPopup(
                kind: FileOperationKind.folder,
                onAction: (action) {
                  Navigator.of(context).pop();
                  _handleFileOperation(action);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _openSelectionMenu() {
    final items = _selectedItems();
    final FileOperationKind kind;
    if (items.length > 1) {
      kind = FileOperationKind.multiple;
    } else if (items.length == 1 && items.first.isFolder) {
      kind = FileOperationKind.folder;
    } else {
      kind = FileOperationKind.file;
    }

    final topPad = MediaQuery.of(context).padding.top;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'selection-menu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              top: topPad + kToolbarHeight + 8,
              right: 8,
              child: FileOperationsPopup(
                kind: kind,
                onAction: (action) {
                  Navigator.of(context).pop();
                  _handleFileOperation(action);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  List<FileItem> _selectedItems() {
    final listing = ref.read(directoryProvider(_path)).valueOrNull;
    if (listing == null) return const [];
    return listing.files.where((f) => _selected.contains(f.path)).toList();
  }

  void _handleFileOperation(FileOperation op) {
    if (op == FileOperation.download) {
      _enqueueDownloads();
      return;
    }
    const labels = {
      FileOperation.open: '打开',
      FileOperation.share: '分享',
      FileOperation.rename: '重命名',
      FileOperation.copy: '复制',
      FileOperation.directLink: '获取直链',
      FileOperation.tag: '标签',
      FileOperation.organize: '整理',
      FileOperation.more: '更多操作',
      FileOperation.details: '详细信息',
      FileOperation.delete: '删除',
    };
    _toast('功能暂未实现：${labels[op]}');
  }

  /// 把当前选中的文件加入下载队列（内部批量获取直链）。
  Future<void> _enqueueDownloads() async {
    final selected = _selectedItems();
    final files = selected.where((f) => !f.isFolder).toList();
    if (files.isEmpty) {
      _toast('文件夹打包下载暂不支持');
      return;
    }
    if (files.length != selected.length) {
      _toast('文件夹打包下载暂不支持，将只下载选中的文件');
    }
    try {
      final count = await ref
          .read(downloadManagerProvider)
          .manager
          .enqueueCloudreveFiles(ref.read(apiProvider), files);
      if (count > 0) {
        _clearSelection(); // 加入队列成功后自动退出多选。
      }
      _toast(count > 0 ? '已加入下载队列：$count 个任务' : '获取下载链接失败');
    } catch (e) {
      print('[HomePage] 加入下载队列失败: $e');
      _toast('加入下载队列失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final listingAsync = ref.watch(directoryProvider(_path));
    // 只读不订阅：角标区域用 ListenableBuilder 单独订阅，避免主页每秒整体重建。
    final downloadManager = ref.read(downloadManagerProvider).manager;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        backgroundColor: context.appColors.contentBg,
        appBar: AppBar(
        backgroundColor: context.appColors.headerBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: '菜单',
          icon: Icon(Icons.menu, color: context.appColors.textPrimary),
          onPressed: _openSidebar,
        ),
        actions: _selected.isEmpty
            ? [
                ListenableBuilder(
                  listenable: downloadManager,
                  builder: (context, _) => _AppBarIconButton(
                    icon: Icons.download_outlined,
                    tooltip: '下载',
                    badgeCount: downloadManager.activeCount,
                    onPressed: _openDownloads,
                  ),
                ),
                _AppBarIconButton(
                  icon: Icons.search,
                  tooltip: '搜索',
                  onPressed: _openSearch,
                ),
                _AppBarIconButton(
                  icon: Icons.add,
                  tooltip: '添加',
                  onPressed: _openAddMenu,
                ),
                SizedBox(
                  width: 44,
                  height: 44,
                  child:
                      Center(child: _UserAvatar(user: user, onTap: _openUserMenu)),
                ),
                const SizedBox(width: 8),
              ]
            : [
                _SelectionActionButton(
                  icon: Icons.close,
                  count: _selected.length,
                  tooltip: '取消选择',
                  onPressed: _clearSelection,
                ),
                _SelectionActionButton(
                  icon: Icons.more_horiz,
                  count: _selected.length,
                  tooltip: '更多操作',
                  onPressed: _openSelectionMenu,
                ),
                const SizedBox(width: 4),
              ],
        bottom: _HeaderToolbar(
          path: _path,
          onNavigate: _navigateTo,
          onToggleView: _openViewPanel,
          onSort: _openSortMenu,
          onMore: _openMoreMenu,
          onOpenBreadcrumb: _openBreadcrumbPopup,
        ),
      ),
      body: listingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: _refresh,
        ),
        data: (listing) => RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: _buildListing(listing),
        ),
      ),
    ),
    );
  }

  void _openMoreMenu() {
    final topPad = MediaQuery.of(context).padding.top;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'more-menu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              top: topPad + kToolbarHeight + 40,
              right: 8,
              child: MoreMenuPopup(
                onAction: (action) {
                  Navigator.of(context).pop();
                  _handleMoreAction(action);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleMoreAction(MoreMenuAction action) {
    switch (action) {
      case MoreMenuAction.refresh:
        _refresh();
        break;
      case MoreMenuAction.pin:
        _toast('固定到侧边栏功能暂未实现');
        break;
      case MoreMenuAction.selectAll:
        final listing = ref.read(directoryProvider(_path)).valueOrNull;
        if (listing != null) {
          setState(() {
            _selected.addAll(listing.files.map((f) => f.path));
          });
        }
        break;
      case MoreMenuAction.deselect:
        setState(() => _selected.clear());
        break;
      case MoreMenuAction.invert:
        final listing = ref.read(directoryProvider(_path)).valueOrNull;
        if (listing != null) {
          final all = listing.files.map((f) => f.path).toSet();
          final inverted = all.difference(_selected);
          setState(() {
            _selected
              ..clear()
              ..addAll(inverted);
          });
        }
        break;
    }
  }

  Widget _buildListing(DirectoryListing listing) {
    final files = listing.files;
    final folders = files.where((f) => f.isFolder).toList();
    final fileItems = files.where((f) => !f.isFolder).toList();

    if (files.isEmpty) {
      return ListView(
        children: const [SizedBox(height: 80), Center(child: Text('此目录为空'))],
      );
    }

    // 列表视图：长方形行
    if (_viewMode == 'list') {
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: files.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final file = files[i];
          return _FileListTile(
            file: file,
            isSelected: _selected.contains(file.path),
            onSelect: () => _toggleSelect(file),
            onOpen: () => _open(file),
          );
        },
      );
    }

    // 网格视图：文件夹 + 文件分两段
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (folders.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _SectionTitle('文件夹'),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 3.0,
            ),
            itemCount: folders.length,
            itemBuilder: (context, i) {
              final folder = folders[i];
              return _FolderCard(
                folder: folder,
                isSelected: _selected.contains(folder.path),
                onSelect: () => _toggleSelect(folder),
                onOpen: () => _open(folder),
              );
            },
          ),
        ],
        if (fileItems.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionTitle('文件'),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemCount: fileItems.length,
            itemBuilder: (context, i) {
              final file = fileItems[i];
              return FileCard(
                file: file,
                isSelected: _selected.contains(file.path),
                showThumb: _thumbnails,
                onSelect: () => _toggleSelect(file),
                onOpen: () => _open(file),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: context.appColors.textPrimary,
      ),
    );
  }
}

/// 顶部导航栏下方的工具栏：面包屑 + 视图/排序/更多分段按钮组。
class _HeaderToolbar extends StatelessWidget implements PreferredSizeWidget {
  final String path;
  final ValueChanged<String> onNavigate;
  final VoidCallback onToggleView;
  final VoidCallback onSort;
  final VoidCallback onMore;
  final VoidCallback onOpenBreadcrumb;

  const _HeaderToolbar({
    required this.path,
    required this.onNavigate,
    required this.onToggleView,
    required this.onSort,
    required this.onMore,
    required this.onOpenBreadcrumb,
  });

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: context.appColors.contentBg, width: 2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Breadcrumb(
              path: path,
              onNavigate: onNavigate,
              onOpenCurrentPopup: onOpenBreadcrumb,
            ),
          ),
          const SizedBox(width: 12),
          _ActionGroup(
            onToggleView: onToggleView,
            onSort: onSort,
            onMore: onMore,
          ),
        ],
      ),
    );
  }
}

/// 面包屑：可左右滑动的路径层级，末尾目录带朝下箭头；路径变化后自动滚到最右。
class _Breadcrumb extends StatefulWidget {
  final String path;
  final ValueChanged<String> onNavigate;
  final VoidCallback onOpenCurrentPopup;

  const _Breadcrumb({
    required this.path,
    required this.onNavigate,
    required this.onOpenCurrentPopup,
  });

  @override
  State<_Breadcrumb> createState() => _BreadcrumbState();
}

class _BreadcrumbState extends State<_Breadcrumb> {
  final ScrollController _controller = ScrollController();

  @override
  void didUpdateWidget(covariant _Breadcrumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _scrollToEnd();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) return;
      _controller.jumpTo(_controller.position.maxScrollExtent);
    });
  }

  List<String> get _segments =>
      widget.path.split('/').where((s) => s.isNotEmpty).toList();

  String _pathFor(int index) =>
      '/${_segments.sublist(0, index + 1).join('/')}';

  /// 面包屑显示用：URL 解码目录名（不改动内部路径）。
  String _decodeSegment(String s) {
    try {
      return Uri.decodeComponent(s);
    } catch (_) {
      return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final segments = _segments;
    return Material(
      color: context.appColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: context.appColors.toolbarBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: SizedBox(
          height: 40,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _crumb(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.home_outlined,
                        size: 18, color: context.appColors.textPrimary),
                    const SizedBox(width: 6),
                    Text('我的文件',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: context.appColors.textPrimary)),
                  ],
                ),
                onTap: () => widget.onNavigate('/'),
              ),
              for (int i = 0; i < segments.length; i++) ...[
                Icon(Icons.chevron_right,
                    size: 16, color: context.appColors.textFaint),
                _crumb(
                  _segmentLabel(
                      _decodeSegment(segments[i]), i == segments.length - 1),
                  onTap: i == segments.length - 1
                      ? widget.onOpenCurrentPopup
                      : () => widget.onNavigate(_pathFor(i)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 面包屑单元：包裹点击，墨水展开区域与面包屑上下边缘留出间距。
  Widget _crumb(Widget child, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: child,
      ),
    );
  }

  /// 目录段标签：末尾段加粗并紧贴一个朝下箭头。
  Widget _segmentLabel(String name, bool isLast) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isLast ? FontWeight.w600 : FontWeight.w500,
            color: context.appColors.textPrimary,
          ),
        ),
        if (isLast)
          Icon(Icons.arrow_drop_down,
              size: 20, color: context.appColors.textSecondary),
      ],
    );
  }
}

/// 分段按钮组：视图 / 排序 / 更多，边框包裹 + 内部竖向分隔线。
class _ActionGroup extends StatelessWidget {
  final VoidCallback onToggleView;
  final VoidCallback onSort;
  final VoidCallback onMore;

  const _ActionGroup({
    required this.onToggleView,
    required this.onSort,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: context.appColors.toolbarBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 40,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionButton(icon: Icons.grid_view_outlined, onTap: onToggleView),
            _ActionButton(icon: Icons.swap_vert, onTap: onSort),
            _ActionButton(icon: Icons.more_horiz, onTap: onMore, last: true),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool last;

  const _ActionButton({
    required this.icon,
    required this.onTap,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(
                  right: BorderSide(color: context.appColors.toolbarBorder)),
        ),
        child: Icon(icon, size: 18, color: context.appColors.textSecondary),
      ),
    );
  }
}

/// 文件夹卡片（横向：图标 + 名字）。
class _FolderCard extends StatelessWidget {
  final FileItem folder;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onOpen;

  const _FolderCard({
    required this.folder,
    required this.isSelected,
    required this.onSelect,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appColors.surfaceMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            InkWell(
              onTap: onSelect,
            child: isSelected
                ? const SelectionCheck(size: 18)
                : Icon(Icons.folder,
                    size: 18, color: context.appColors.textSecondary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: onOpen,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  folder.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14, color: context.appColors.textPrimary),
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

/// 列表视图（长方形行）。
class _FileListTile extends StatelessWidget {
  final FileItem file;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onOpen;

  const _FileListTile({
    required this.file,
    required this.isSelected,
    required this.onSelect,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: IconButton(
        tooltip: '选择',
        icon: isSelected
            ? const SelectionCheck(size: 22)
            : Icon(fileIcon(file),
                color: fileIconColor(context, file), size: 28),
        onPressed: onSelect,
      ),
      title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(file.isFolder ? '文件夹' : formatSize(file.size)),
      selected: isSelected,
      selectedTileColor: scheme.primary.withAlpha(46),
      onTap: onOpen,
    );
  }
}

/// 右上角用户头像。
class _UserAvatar extends StatelessWidget {
  final User? user;
  final VoidCallback onTap;

  const _UserAvatar({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = user?.nickname ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: CircleAvatar(
        radius: 16,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Text(
          initial,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}

/// 选择模式下的导航栏按钮：右上角带蓝色圆形数量角标。
class _SelectionActionButton extends StatelessWidget {
  final IconData icon;
  final int count;
  final String tooltip;
  final VoidCallback onPressed;

  const _SelectionActionButton({
    required this.icon,
    required this.count,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          IconButton(
            tooltip: tooltip,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            icon: Icon(icon,
                size: 22, color: context.appColors.textPrimary),
            onPressed: onPressed,
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 导航栏图标按钮：固定 44x44，与头像等其他 actions 对齐；可带数量角标。
class _AppBarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final int badgeCount;

  const _AppBarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          IconButton(
            tooltip: tooltip,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            icon: Icon(icon,
                size: 22, color: context.appColors.textPrimary),
            onPressed: onPressed,
          ),
          if (badgeCount > 0)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints:
                    const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}


