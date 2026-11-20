import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n/app_localizations.dart';
import '../core/network/cloudreve_api.dart';
import '../core/theme/app_colors.dart';
import '../models/file_item.dart';
import '../providers/api_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/directory_provider.dart';
import '../providers/download_provider.dart';
import '../providers/file_browser_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/upload_provider.dart';
import '../widgets/common/app_bar_icon_button.dart';
import '../widgets/common/error_view.dart';
import '../widgets/common/selection_actions.dart';
import '../widgets/common/user_avatar.dart';
import '../widgets/file/file_icon.dart';
import '../widgets/file_browser/file_browser_view.dart';
import '../widgets/home/delete_confirm_dialog.dart';
import '../widgets/home/home_popups.dart';
import '../widgets/home/home_toolbar.dart';
import '../widgets/popup/add_menu_popup.dart';
import '../widgets/popup/file_operations_popup.dart';
import '../widgets/popup/more_menu_popup.dart';
import '../widgets/popup/sort_popup.dart';
import '../widgets/popup/user_menu_popup.dart';
import '../widgets/sheet/file_info_sheet.dart';
import '../widgets/sheet/share_create_sheet.dart';
import '../widgets/viewer/image_viewer.dart';
import '../widgets/viewer/video_player_viewer.dart';
import 'downloads_page.dart';
import 'my_shares_page.dart';
import 'settings_hub_page.dart';
import 'share_viewer_page.dart';
import 'trash_page.dart';
import 'upload_queue_page.dart';

/// 文件浏览主页。
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  FileCategory? _category;
  String _searchKeyword = '';
  DateTime? _lastBackPress;

  /// 是否处于「与我共享」视图（列出收藏的分享链接）。
  bool _sharedWithMe = false;

  /// 工具栏「排序」按钮，作为排序菜单的锚点。
  final GlobalKey _sortButtonKey = GlobalKey();

  /// 工具栏「视图」按钮，作为视图面板的锚点。
  final GlobalKey _viewButtonKey = GlobalKey();

  /// 以下为各悬浮窗的锚点。
  final GlobalKey _menuButtonKey = GlobalKey();
  final GlobalKey _userMenuKey = GlobalKey();
  final GlobalKey _addMenuKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _breadcrumbKey = GlobalKey();
  final GlobalKey _selectionMoreKey = GlobalKey();
  final GlobalKey _moreMenuKey = GlobalKey();

  bool get _isSearchActive => _searchKeyword.trim().isNotEmpty;

  /// 浏览状态（路径 / 视图 / 选择），由 [homeFileBrowserProvider] 持有。
  FileBrowserState get _browse => ref.read(homeFileBrowserProvider);

  FileBrowserController get _browseCtrl =>
      ref.read(homeFileBrowserProvider.notifier);

  /// 当前目录路径（`/a/b`，根为 `/`）。
  String get _path => '/${_browse.pathSegments.join('/')}';

  /// 当前排序选项（空 key 时为 null，表示沿用服务端默认）。
  SortOption? _sort() => sortOptionFor(_browse.sortKey);

  /// 当前目录 + 排序 + 分页组成的查询（任一变化都会自动重新拉取）。
  DirectoryQuery get _directoryQuery {
    final sort = _sort();
    return DirectoryQuery(
      _path,
      orderBy: sort?.orderBy,
      orderDirection: sort?.orderDirection,
      pageSize: _browse.pageSize,
    );
  }

  /// 搜索查询：关键字 + 排序 + 分页。
  SearchQuery get _searchQuery {
    final sort = _sort();
    return SearchQuery(
      _searchKeyword.trim(),
      orderBy: sort?.orderBy,
      orderDirection: sort?.orderDirection,
      pageSize: _browse.pageSize,
    );
  }

  /// 分类查询：分类 + 排序 + 分页（仅在分类视图下使用）。
  CategoryQuery get _categoryQuery {
    final sort = _sort();
    return CategoryQuery(
      _category!,
      orderBy: sort?.orderBy,
      orderDirection: sort?.orderDirection,
      pageSize: _browse.pageSize,
    );
  }

  List<String> _segmentsOf(String path) =>
      path.split('/').where((s) => s.isNotEmpty).toList();

  void _enter(FileItem folder) {
    _browseCtrl.setPath(_segmentsOf(folder.relativePath));
    setState(() {
      _category = null;
      _sharedWithMe = false;
      _searchKeyword = '';
    });
  }

  /// 侧边栏目录跳转：收藏的分享链接直接打开分享，其余按路径进入。
  void _openSidebarFolder(FileItem folder) {
    if (folder.isShareShortcut) {
      _openShareShortcut(folder);
      return;
    }
    _navigateTo(folder.relativePath);
  }

  /// 侧边栏/目录跳转：接收完整路径。
  void _navigateTo(String path) {
    _browseCtrl.setPath(_segmentsOf(path));
    setState(() {
      _category = null;
      _sharedWithMe = false;
      _searchKeyword = '';
    });
  }

  /// 面包屑跳转：0 = 根，i = 保留前 i 段。
  void _navigateToDepth(int depth) {
    _browseCtrl.setPath(_browse.pathSegments.take(depth).toList());
    setState(() {
      _category = null;
      _sharedWithMe = false;
      _searchKeyword = '';
    });
  }

  /// 打开侧边栏分类（图片 / 视频 / 音乐 / 文档）。
  void _openCategory(FileCategory category) {
    _browseCtrl.setPath(const []);
    setState(() {
      _category = category;
      _sharedWithMe = false;
      _searchKeyword = '';
    });
  }

  /// 打开「与我共享」视图：和图片 / 视频等分类一样，直接在主界面展示。
  void _openSharedWithMe() {
    _browseCtrl.setPath(const []);
    setState(() {
      _category = null;
      _sharedWithMe = true;
      _searchKeyword = '';
    });
  }

  /// 系统返回键：多选时先取消选择；否则分类/非根目录返回上一级，根目录两次返回退出。
  void _handleBackPress() {
    if (_browse.selectedPaths.isNotEmpty) {
      _clearSelection();
      return;
    }
    if (_isSearchActive) {
      setState(() => _searchKeyword = '');
      return;
    }
    if (_sharedWithMe) {
      setState(() => _sharedWithMe = false);
      return;
    }
    if (_category != null) {
      setState(() => _category = null);
      return;
    }
    if (!_browse.isRoot) {
      _goUp();
      return;
    }
    final now = DateTime.now();
    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      _toast(AppLocalizations.of(context).t('再按一次返回键退出软件'));
    } else {
      SystemNavigator.pop();
    }
  }

  void _refresh() {
    if (_sharedWithMe) {
      ref.invalidate(sharedWithMeProvider);
      return;
    }
    final category = _category;
    if (_isSearchActive) {
      if (category != null) {
        ref.invalidate(categoryFilesProvider(_categoryQuery));
      } else {
        ref.invalidate(searchFilesProvider(_searchQuery));
      }
      return;
    }
    if (category != null) {
      ref.invalidate(categoryFilesProvider(_categoryQuery));
    } else {
      ref.invalidate(directoryProvider(_directoryQuery));
    }
  }

  /// 当前页面展示的文件列表（与我共享 / 搜索 / 分类 / 普通目录）。
  List<FileItem> _currentFiles() {
    if (_sharedWithMe) {
      return _shapeSharedFiles(
        ref.read(sharedWithMeProvider).valueOrNull ?? const [],
      );
    }
    final keyword = _searchKeyword.trim();
    final category = _category;
    if (_isSearchActive) {
      if (category != null) {
        final files =
            ref.read(categoryFilesProvider(_categoryQuery)).valueOrNull ??
                const [];
        return _filterByQuery(files, keyword);
      }
      return ref.read(searchFilesProvider(_searchQuery)).valueOrNull ??
          const [];
    }
    if (category != null) {
      return ref.read(categoryFilesProvider(_categoryQuery)).valueOrNull ??
          const [];
    }
    final listing = ref.read(directoryProvider(_directoryQuery)).valueOrNull;
    return listing?.files ?? const <FileItem>[];
  }

  /// 分类结果内的关键词过滤（原版 Cloudreve 分类视图不支持搜索，这里做本地过滤）。
  List<FileItem> _filterByQuery(List<FileItem> files, String keyword) {
    final q = keyword.toLowerCase();
    return files.where((f) => f.name.toLowerCase().contains(q)).toList();
  }

  /// 「与我共享」列表：关键字本地过滤 + 按当前排序规则排序。
  List<FileItem> _shapeSharedFiles(List<FileItem> files) {
    final keyword = _searchKeyword.trim();
    final list = keyword.isEmpty ? files : _filterByQuery(files, keyword);
    final sort = _sort();
    if (sort == null) return list;
    final sorted = [...list];
    sorted.sort(
        (a, b) => compareFileItems(a, b, sort.orderBy, sort.orderDirection));
    return sorted;
  }

  void _toggleSelect(FileItem file) => _browseCtrl.toggleSelect(file.path);

  void _clearSelection() => _browseCtrl.clearSelection();

  void _open(FileItem file) {
    if (file.isShareShortcut) {
      _openShareShortcut(file);
      return;
    }
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

  /// 打开「收藏的分享链接」：真实地址在 metadata 里，打开的是分享页，
  /// 而不是本地那个空的快捷方式目录。
  void _openShareShortcut(FileItem file) {
    final site = ref.read(currentSiteProvider);
    final redirect = file.sharedRedirect;
    if (site == null || redirect == null) {
      _toast(tr('无法打开该分享'));
      return;
    }
    final parsed = parseShareLinkFromText(redirect, site.baseUrl);
    if (parsed == null) {
      _toast(tr('分享链接格式无法识别'));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShareViewerPage(
          site: site,
          shareId: parsed.shareId,
          password: parsed.password,
        ),
      ),
    );
  }

  void _openVideoPlayer(FileItem file) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerViewer(file: file),
      ),
    );
  }

  void _openImageViewer(FileItem file) {
    final found = _currentFiles().where(isImage).toList();
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
    showHomeSidebar(
      context,
      anchorKey: _menuButtonKey,
      onNavigate: _openSidebarFolder,
      onPlaceholder: () => _toast(AppLocalizations.of(context).t('功能暂未实现')),
      onCycleTheme: _cycleTheme,
      onCategory: _openCategory,
      onDownloads: _openDownloads,
      onTrash: _openTrash,
      onMyShares: _openMyShares,
      sharedWithMeActive: _sharedWithMe,
      onSharedWithMe: _openSharedWithMe,
      onSettings: _openSettings,
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsHubPage()),
    );
  }

  void _openDownloads() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DownloadsPage()),
    );
  }

  void _openTrash() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TrashPage()),
    );
  }

  void _openMyShares() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MySharesPage()),
    );
  }

  void _openUploadQueue() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UploadQueuePage(targetDirUri: pathToUri(_path)),
      ),
    );
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform
        .pickFiles(allowMultiple: true, withData: false);
    if (result == null || !mounted) return;
    final paths = result.files.map((f) => f.path).whereType<String>().toList();
    if (paths.isEmpty) return;
    final site = ref.read(currentSiteProvider);
    if (site == null) return;
    final count = await ref.read(uploadManagerProvider).manager.enqueueFiles(
        paths: paths, siteId: site.id, targetDirUri: pathToUri(_path));
    if (!mounted) return;
    if (count > 0) {
      _openUploadQueue();
    } else {
      _toast(tr('未选择可上传的文件'));
    }
  }

  void _openUserMenu() {
    showHomeUserMenu(
      context,
      anchorKey: _userMenuKey,
      user: ref.read(authProvider).user,
      onAction: _handleUserMenuAction,
    );
  }

  void _handleUserMenuAction(UserMenuAction action) {
    switch (action) {
      case UserMenuAction.logout:
        final site = ref.read(currentSiteProvider);
        if (site != null) {
          ref.read(authProvider.notifier).signOut(site);
        }
        break;
      case UserMenuAction.managePanel:
      case UserMenuAction.settings:
      case UserMenuAction.profile:
        _toast(tr('功能暂未实现'));
        break;
    }
  }

  void _openAddMenu() {
    showHomeAddMenu(
      context,
      anchorKey: _addMenuKey,
      onAction: (action) {
        if (action == AddMenuAction.uploadFile) {
          _pickAndUpload();
        } else {
          _toast(tr('功能暂未实现'));
        }
      },
    );
  }

  void _openSearch() {
    showHomeSearch(
      context,
      anchorKey: _searchKey,
      onSubmitted: (query) {
        final keyword = query.trim();
        if (keyword.isEmpty) return;
        _browseCtrl.clearSelection();
        setState(() => _searchKeyword = keyword);
      },
    );
  }

  void _openViewPanel() {
    final browse = _browse;
    final ctrl = _browseCtrl;
    showHomeViewPanel(
      context,
      anchorKey: _viewButtonKey,
      viewMode: browse.viewMode,
      thumbnails: browse.thumbnails,
      pageSize: browse.pageSize,
      onViewModeChanged: ctrl.setViewMode,
      onThumbnailsChanged: ctrl.setThumbnails,
      onPageSizeChanged: ctrl.setPageSize,
    );
  }

  void _openSortMenu() {
    showSortMenu(
      context,
      anchorKey: _sortButtonKey,
      selected: _browse.sortKey,
      onSelected: _browseCtrl.setSortKey,
    );
  }

  void _openBreadcrumbPopup() {
    showFileOperations(
      context,
      anchorKey: _breadcrumbKey,
      operations: fileOperationsFor(FileOperationKind.folder),
      onAction: _handleFileOperation,
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
    showFileOperations(
      context,
      anchorKey: _selectionMoreKey,
      operations: fileOperationsFor(kind),
      onAction: _handleFileOperation,
    );
  }

  List<FileItem> _selectedItems() {
    final selected = _browse.selectedPaths;
    return _currentFiles().where((f) => selected.contains(f.path)).toList();
  }

  /// 返回上一级目录。
  void _goUp() {
    final segments = _browse.pathSegments;
    if (segments.isEmpty) return;
    _browseCtrl.setPath(segments.sublist(0, segments.length - 1));
  }

  void _handleFileOperation(FileOperation op) {
    if (op == FileOperation.download) {
      _enqueueDownloads();
      return;
    }
    if (op == FileOperation.delete) {
      _deleteSelected();
      return;
    }
    if (op == FileOperation.share) {
      _shareSingleItem();
      return;
    }
    if (op == FileOperation.selectAll) {
      _browseCtrl.selectAll(_currentFiles());
      return;
    }
    if (op == FileOperation.invert) {
      _browseCtrl.invertSelection(_currentFiles());
      return;
    }
    final labels = {
      FileOperation.open: tr('打开'),
      FileOperation.rename: tr('重命名'),
      FileOperation.copy: tr('复制'),
      FileOperation.directLink: tr('获取直链'),
      FileOperation.tag: tr('标签'),
      FileOperation.organize: tr('整理'),
      FileOperation.more: tr('更多操作'),
      FileOperation.details: tr('详细信息'),
    };
    _toast(tr('功能暂未实现：{action}', args: {'action': labels[op] ?? ''}));
  }

  /// 对当前选中的单个文件/文件夹（或无选中时的当前文件夹）发起分享。
  void _shareSingleItem() {
    final selected = _selectedItems();
    if (selected.length > 1) {
      _toast(tr('一次只能分享一个文件或文件夹'));
      return;
    }
    FileItem target;
    if (selected.length == 1) {
      target = selected.first;
    } else if (_path != '/' && _category == null && !_isSearchActive) {
      final name = _path.split('/').where((s) => s.isNotEmpty).last;
      target = FileItem(
        type: 1,
        id: '',
        name: name,
        path: pathToUri(_path),
      );
    } else {
      _toast(tr('请先选择要分享的文件或文件夹'));
      return;
    }
    _showCreateShare(target);
  }

  /// 弹出创建分享面板：创建结果与复制操作在面板内完成。
  Future<void> _showCreateShare(FileItem target) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareCreateSheet(file: target),
    );
  }

  /// 删除选中文件/文件夹，支持“移入回收站 / 彻底删除 / 保留物理文件”。
  Future<void> _deleteSelected() async {
    var selected = _selectedItems();
    var deletingCurrentFolder = false;
    if (selected.isEmpty) {
      // 面包屑里的“删除”针对当前目录本身；根目录不处理。
      if (_path == '/' || _category != null || _isSearchActive) {
        _toast(tr('没有可删除的选中文件'));
        return;
      }
      deletingCurrentFolder = true;
      final name = _path.split('/').where((s) => s.isNotEmpty).last;
      selected = [
        FileItem(
          type: 1,
          id: '',
          name: name,
          path: pathToUri(_path),
        ),
      ];
    }

    final options = await showDeleteConfirmDialog(
      context,
      count: selected.length,
    );
    if (options == null || !mounted) return;

    try {
      await ref.read(apiProvider).deleteFiles(
            uris: selected.map((f) => f.path).toList(),
            unlink: options.unlink,
            skipSoftDelete: options.skipSoftDelete,
          );
      if (!mounted) return;
      if (deletingCurrentFolder) {
        _goUp();
      } else {
        _clearSelection();
        _refresh();
      }
      _toast(options.skipSoftDelete ? tr('已彻底删除') : tr('已移入回收站'));
    } catch (e) {
      print('[HomePage] 删除文件失败: $e');
      if (mounted) _toast(tr('删除失败，请重试'));
    }
  }

  /// 把当前选中的文件加入下载队列（内部批量获取直链）。
  Future<void> _enqueueDownloads() async {
    final selected = _selectedItems();
    final files = selected.where((f) => !f.isFolder).toList();
    if (files.isEmpty) {
      _toast(tr('文件夹打包下载暂不支持'));
      return;
    }
    if (files.length != selected.length) {
      _toast(tr('文件夹打包下载暂不支持，将只下载选中的文件'));
    }
    try {
      final count = await ref
          .read(downloadManagerProvider)
          .manager
          .enqueueCloudreveFiles(ref.read(apiProvider), files);
      if (count > 0) {
        _clearSelection(); // 加入队列成功后自动退出多选。
      }
      _toast(count > 0
          ? tr('已加入下载队列：{count} 个任务', args: {'count': count})
          : tr('获取下载链接失败'));
    } catch (e) {
      print('[HomePage] 加入下载队列失败: $e');
      _toast(tr('加入下载队列失败'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authProvider).user;
    final browse = ref.watch(homeFileBrowserProvider);
    // 只读不订阅：角标区域用 ListenableBuilder 单独订阅，避免主页每秒整体重建。
    final downloadManager = ref.read(downloadManagerProvider).manager;
    final uploadManager = ref.read(uploadManagerProvider).manager;

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
            key: _menuButtonKey,
            tooltip: l10n.t('菜单'),
            icon: Icon(Icons.menu, color: context.appColors.textPrimary),
            onPressed: _openSidebar,
          ),
          actions: browse.selectedPaths.isEmpty
              ? [
                  ListenableBuilder(
                    listenable: uploadManager,
                    builder: (context, _) => AppBarIconButton(
                      icon: Icons.upload_outlined,
                      tooltip: l10n.t('上传'),
                      badgeCount: uploadManager.activeCount,
                      onPressed: _openUploadQueue,
                    ),
                  ),
                  ListenableBuilder(
                    listenable: downloadManager,
                    builder: (context, _) => AppBarIconButton(
                      icon: Icons.download_outlined,
                      tooltip: l10n.t('下载'),
                      badgeCount: downloadManager.activeCount,
                      onPressed: _openDownloads,
                    ),
                  ),
                  AppBarIconButton(
                    key: _searchKey,
                    icon: Icons.search,
                    tooltip: l10n.t('搜索'),
                    onPressed: _openSearch,
                  ),
                  AppBarIconButton(
                    key: _addMenuKey,
                    icon: Icons.add,
                    tooltip: l10n.t('添加'),
                    onPressed: _openAddMenu,
                  ),
                  SizedBox(
                    key: _userMenuKey,
                    width: 44,
                    height: 44,
                    child: Center(
                        child: UserAvatar(user: user, onTap: _openUserMenu)),
                  ),
                  const SizedBox(width: 8),
                ]
              : [
                  SelectionActions(
                    count: browse.selectedPaths.length,
                    onClear: _clearSelection,
                    onMore: _openSelectionMenu,
                    moreButtonKey: _selectionMoreKey,
                  ),
                ],
          bottom: HomeToolbar(
            segments: _sharedWithMe ? const [] : browse.pathSegments,
            category: _sharedWithMe ? null : _category,
            rootLabel: _sharedWithMe ? l10n.t('与我共享') : l10n.t('我的文件'),
            rootIcon:
                _sharedWithMe ? Icons.people_outline : Icons.home_outlined,
            viewButtonKey: _viewButtonKey,
            sortButtonKey: _sortButtonKey,
            breadcrumbKey: _breadcrumbKey,
            moreButtonKey: _moreMenuKey,
            onNavigate: _navigateToDepth,
            onToggleView: _openViewPanel,
            onSort: _openSortMenu,
            onMore: _openMoreMenu,
            onOpenBreadcrumb: _openBreadcrumbPopup,
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final keyword = _searchKeyword.trim();
    final category = _category;

    if (_sharedWithMe) {
      final filesAsync = ref.watch(sharedWithMeProvider);
      return filesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(message: e.toString(), onRetry: _refresh),
        data: (files) => RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: _buildListing(
            DirectoryListing(files: _shapeSharedFiles(files)),
          ),
        ),
      );
    }

    if (_isSearchActive) {
      if (category != null) {
        final filesAsync = ref.watch(categoryFilesProvider(_categoryQuery));
        return filesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: _refresh,
          ),
          data: (files) => _buildSearchResults(
            _filterByQuery(files, keyword),
            keyword: keyword,
          ),
        );
      }
      final filesAsync = ref.watch(searchFilesProvider(_searchQuery));
      return filesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: _refresh,
        ),
        data: (files) => _buildSearchResults(files, keyword: keyword),
      );
    }

    if (category != null) {
      final filesAsync = ref.watch(categoryFilesProvider(_categoryQuery));
      return filesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: _refresh,
        ),
        data: (files) => RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: _buildListing(DirectoryListing(files: files)),
        ),
      );
    }
    final listingAsync = ref.watch(directoryProvider(_directoryQuery));
    return listingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: _refresh,
      ),
      data: (listing) => RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: _buildListing(listing),
      ),
    );
  }

  Widget _buildSearchResults(List<FileItem> files, {required String keyword}) {
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: files.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 80),
                Center(
                    child: Text(tr('未找到与“{keyword}”相关的文件',
                        args: {'keyword': keyword}))),
              ],
            )
          : _buildListing(DirectoryListing(files: files)),
    );
  }

  void _openMoreMenu() {
    showHomeMoreMenu(
      context,
      anchorKey: _moreMenuKey,
      onAction: _handleMoreAction,
    );
  }

  void _handleMoreAction(MoreMenuAction action) {
    final ctrl = _browseCtrl;
    switch (action) {
      case MoreMenuAction.refresh:
        _refresh();
        break;
      case MoreMenuAction.pin:
        _toast(tr('固定到侧边栏功能暂未实现'));
        break;
      case MoreMenuAction.selectAll:
        ctrl.selectAll(_currentFiles());
        break;
      case MoreMenuAction.deselect:
        ctrl.clearSelection();
        break;
      case MoreMenuAction.invert:
        ctrl.invertSelection(_currentFiles());
        break;
    }
  }

  Widget _buildListing(DirectoryListing listing) {
    final browse = _browse;
    return FileBrowserView(
      files: listing.files,
      viewMode: browse.viewMode,
      showThumbnails: browse.thumbnails,
      selectedPaths: browse.selectedPaths,
      onOpen: _open,
      onSelect: _toggleSelect,
    );
  }
}
