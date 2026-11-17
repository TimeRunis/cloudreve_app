import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/cloudreve_api.dart';
import '../core/theme/app_colors.dart';
import '../models/file_item.dart';
import '../providers/api_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/directory_provider.dart';
import '../providers/download_provider.dart';
import '../providers/file_browser_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/site_config_provider.dart';
import '../providers/upload_provider.dart';
import '../widgets/common/app_bar_icon_button.dart';
import '../widgets/common/error_view.dart';
import '../widgets/common/user_avatar.dart';
import '../widgets/file/file_icon.dart';
import '../widgets/file_browser/file_browser_view.dart';
import '../widgets/home/home_popups.dart';
import '../widgets/home/home_toolbar.dart';
import '../widgets/popup/add_menu_popup.dart';
import '../widgets/popup/file_operations_popup.dart';
import '../widgets/popup/more_menu_popup.dart';
import '../widgets/popup/user_menu_popup.dart';
import '../widgets/sheet/file_info_sheet.dart';
import '../widgets/sheet/share_create_sheet.dart';
import '../widgets/viewer/image_viewer.dart';
import '../widgets/viewer/video_player_viewer.dart';
import 'downloads_page.dart';
import 'my_shares_page.dart';
import 'settings_hub_page.dart';
import 'site_list_page.dart';
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

  bool get _isSearchActive => _searchKeyword.trim().isNotEmpty;

  /// 浏览状态（路径 / 视图 / 选择），由 [homeFileBrowserProvider] 持有。
  FileBrowserState get _browse => ref.read(homeFileBrowserProvider);

  FileBrowserController get _browseCtrl =>
      ref.read(homeFileBrowserProvider.notifier);

  /// 当前目录路径（`/a/b`，根为 `/`）。
  String get _path => '/${_browse.pathSegments.join('/')}';

  List<String> _segmentsOf(String path) =>
      path.split('/').where((s) => s.isNotEmpty).toList();

  void _enter(FileItem folder) {
    _browseCtrl.setPath(_segmentsOf(folder.relativePath));
    setState(() {
      _category = null;
      _searchKeyword = '';
    });
  }

  /// 侧边栏/目录跳转：接收完整路径。
  void _navigateTo(String path) {
    _browseCtrl.setPath(_segmentsOf(path));
    setState(() {
      _category = null;
      _searchKeyword = '';
    });
  }

  /// 面包屑跳转：0 = 根，i = 保留前 i 段。
  void _navigateToDepth(int depth) {
    _browseCtrl.setPath(_browse.pathSegments.take(depth).toList());
    setState(() {
      _category = null;
      _searchKeyword = '';
    });
  }

  /// 打开侧边栏分类（图片 / 视频 / 音乐 / 文档）。
  void _openCategory(FileCategory category) {
    _browseCtrl.setPath(const []);
    setState(() {
      _category = category;
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
      _toast('再按一次返回键退出软件');
    } else {
      SystemNavigator.pop();
    }
  }

  void _refresh() {
    final keyword = _searchKeyword.trim();
    final category = _category;
    if (_isSearchActive) {
      if (category != null) {
        ref.invalidate(categoryFilesProvider(category));
      } else {
        ref.invalidate(searchFilesProvider(keyword));
      }
      return;
    }
    if (category != null) {
      ref.invalidate(categoryFilesProvider(category));
    } else {
      ref.invalidate(directoryProvider(_path));
    }
  }

  /// 当前页面展示的文件列表（搜索 / 分类 / 普通目录）。
  List<FileItem> _currentFiles() {
    final keyword = _searchKeyword.trim();
    final category = _category;
    if (_isSearchActive) {
      if (category != null) {
        final files =
            ref.read(categoryFilesProvider(category)).valueOrNull ?? const [];
        return _filterByQuery(files, keyword);
      }
      return ref.read(searchFilesProvider(keyword)).valueOrNull ?? const [];
    }
    if (category != null) {
      return ref.read(categoryFilesProvider(category)).valueOrNull ?? const [];
    }
    final listing = ref.read(directoryProvider(_path)).valueOrNull;
    return listing?.files ?? const <FileItem>[];
  }

  /// 分类结果内的关键词过滤（原版 Cloudreve 分类视图不支持搜索，这里做本地过滤）。
  List<FileItem> _filterByQuery(List<FileItem> files, String keyword) {
    final q = keyword.toLowerCase();
    return files.where((f) => f.name.toLowerCase().contains(q)).toList();
  }

  void _toggleSelect(FileItem file) => _browseCtrl.toggleSelect(file.path);

  void _clearSelection() => _browseCtrl.clearSelection();

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
    final title =
        ref.read(siteConfigProvider).valueOrNull?.title ?? 'Cloudreve';
    showHomeSidebar(
      context,
      title: title,
      onNavigate: _navigateTo,
      onPlaceholder: () => _toast('功能暂未实现'),
      onCycleTheme: _cycleTheme,
      onCategory: _openCategory,
      onManageSites: _openManageSites,
      onDownloads: _openDownloads,
      onTrash: _openTrash,
      onMyShares: _openMyShares,
      onSettings: _openSettings,
    );
  }

  void _openManageSites() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SiteListPage()),
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
      _toast('未选择可上传的文件');
    }
  }

  void _openUserMenu() {
    showHomeUserMenu(
      context,
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
        _toast('功能暂未实现');
        break;
    }
  }

  void _openAddMenu() {
    showHomeAddMenu(
      context,
      onAction: (action) {
        if (action == AddMenuAction.uploadFile) {
          _pickAndUpload();
        } else {
          _toast('功能暂未实现：$action');
        }
      },
    );
  }

  void _openSearch() {
    showHomeSearch(
      context,
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
      viewMode: browse.viewMode,
      thumbnails: browse.thumbnails,
      pageSize: browse.pageSize,
      onViewModeChanged: ctrl.setViewMode,
      onThumbnailsChanged: ctrl.setThumbnails,
      onPageSizeChanged: ctrl.setPageSize,
    );
  }

  void _openSortMenu() {
    showHomeSortMenu(
      context,
      selected: _browse.sortKey,
      onSelected: _browseCtrl.setSortKey,
    );
  }

  void _openBreadcrumbPopup() {
    showHomeFolderOperations(context, onAction: _handleFileOperation);
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
    showHomeSelectionOperations(
      context,
      kind: kind,
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
    const labels = {
      FileOperation.open: '打开',
      FileOperation.rename: '重命名',
      FileOperation.copy: '复制',
      FileOperation.directLink: '获取直链',
      FileOperation.tag: '标签',
      FileOperation.organize: '整理',
      FileOperation.more: '更多操作',
      FileOperation.details: '详细信息',
    };
    _toast('功能暂未实现：${labels[op]}');
  }

  /// 对当前选中的单个文件/文件夹（或无选中时的当前文件夹）发起分享。
  void _shareSingleItem() {
    final selected = _selectedItems();
    if (selected.length > 1) {
      _toast('一次只能分享一个文件或文件夹');
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
      _toast('请先选择要分享的文件或文件夹');
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
        _toast('没有可删除的选中文件');
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

    var skipSoftDelete = false;
    var unlink = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('删除 ${selected.length} 项'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '选择删除方式：',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.appColors.textSecondary,
                      ),
                    ),
                    RadioListTile<bool>(
                      value: false,
                      groupValue: skipSoftDelete,
                      title: const Text('移入回收站'),
                      subtitle: const Text('可恢复（取决于站点回收站设置）'),
                      onChanged: (v) =>
                          setDialogState(() => skipSoftDelete = v ?? false),
                    ),
                    RadioListTile<bool>(
                      value: true,
                      groupValue: skipSoftDelete,
                      title: const Text('彻底删除'),
                      subtitle: const Text('跳过回收站，不可恢复'),
                      onChanged: (v) =>
                          setDialogState(() => skipSoftDelete = v ?? true),
                    ),
                    const Divider(),
                    CheckboxListTile(
                      value: unlink,
                      onChanged: (v) =>
                          setDialogState(() => unlink = v ?? false),
                      title: const Text('保留物理文件'),
                      subtitle: const Text('解除引用并保留底层文件，需用户组高级删除权限'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('确认删除'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(apiProvider).deleteFiles(
            uris: selected.map((f) => f.path).toList(),
            unlink: unlink,
            skipSoftDelete: skipSoftDelete,
          );
      if (!mounted) return;
      if (deletingCurrentFolder) {
        _goUp();
      } else {
        _clearSelection();
        _refresh();
      }
      _toast(skipSoftDelete ? '已彻底删除' : '已移入回收站');
    } catch (e) {
      print('[HomePage] 删除文件失败: $e');
      if (mounted) _toast('删除失败，请重试');
    }
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
            tooltip: '菜单',
            icon: Icon(Icons.menu, color: context.appColors.textPrimary),
            onPressed: _openSidebar,
          ),
          actions: browse.selectedPaths.isEmpty
              ? [
                  ListenableBuilder(
                    listenable: uploadManager,
                    builder: (context, _) => AppBarIconButton(
                      icon: Icons.upload_outlined,
                      tooltip: '上传',
                      badgeCount: uploadManager.activeCount,
                      onPressed: _openUploadQueue,
                    ),
                  ),
                  ListenableBuilder(
                    listenable: downloadManager,
                    builder: (context, _) => AppBarIconButton(
                      icon: Icons.download_outlined,
                      tooltip: '下载',
                      badgeCount: downloadManager.activeCount,
                      onPressed: _openDownloads,
                    ),
                  ),
                  AppBarIconButton(
                    icon: Icons.search,
                    tooltip: '搜索',
                    onPressed: _openSearch,
                  ),
                  AppBarIconButton(
                    icon: Icons.add,
                    tooltip: '添加',
                    onPressed: _openAddMenu,
                  ),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                        child: UserAvatar(user: user, onTap: _openUserMenu)),
                  ),
                  const SizedBox(width: 8),
                ]
              : [
                  AppBarIconButton(
                    icon: Icons.close,
                    badgeCount: browse.selectedPaths.length,
                    badgeOffset: const Offset(4, 4),
                    tooltip: '取消选择',
                    onPressed: _clearSelection,
                  ),
                  AppBarIconButton(
                    icon: Icons.more_horiz,
                    badgeCount: browse.selectedPaths.length,
                    badgeOffset: const Offset(4, 4),
                    tooltip: '更多操作',
                    onPressed: _openSelectionMenu,
                  ),
                  const SizedBox(width: 4),
                ],
          bottom: HomeToolbar(
            segments: browse.pathSegments,
            category: _category,
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

    if (_isSearchActive) {
      if (category != null) {
        final filesAsync = ref.watch(categoryFilesProvider(category));
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
      final filesAsync = ref.watch(searchFilesProvider(keyword));
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
      final filesAsync = ref.watch(categoryFilesProvider(category));
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
    final listingAsync = ref.watch(directoryProvider(_path));
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
                Center(child: Text('未找到与“$keyword”相关的文件')),
              ],
            )
          : _buildListing(DirectoryListing(files: files)),
    );
  }

  void _openMoreMenu() {
    showHomeMoreMenu(context, onAction: _handleMoreAction);
  }

  void _handleMoreAction(MoreMenuAction action) {
    final ctrl = _browseCtrl;
    switch (action) {
      case MoreMenuAction.refresh:
        _refresh();
        break;
      case MoreMenuAction.pin:
        _toast('固定到侧边栏功能暂未实现');
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
