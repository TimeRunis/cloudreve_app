import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../core/network/cloudreve_api.dart';
import '../core/theme/app_colors.dart';
import '../models/file_item.dart';
import '../models/share.dart';
import '../models/site.dart';
import '../providers/api_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/directory_provider.dart';
import '../providers/download_provider.dart';
import '../providers/file_browser_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/common/error_view.dart';
import '../widgets/common/selection_actions.dart';
import '../widgets/common/toolbar_action_group.dart';
import '../widgets/file/file_icon.dart';
import '../widgets/file/view_panel.dart';
import '../widgets/file_browser/file_browser_view.dart';
import '../widgets/navigation/breadcrumb.dart';
import '../widgets/picker/cloud_folder_picker.dart';
import '../widgets/popup/app_popup.dart';
import '../widgets/popup/file_operations_popup.dart';
import '../widgets/popup/popup_item.dart';
import '../widgets/popup/sort_popup.dart';
import '../widgets/share/share_password_view.dart';
import '../widgets/sheet/file_info_sheet.dart';
import '../widgets/viewer/image_viewer.dart';
import '../widgets/viewer/video_player_viewer.dart';
import 'downloads_page.dart';
import '../core/i18n/app_localizations.dart';

/// 分享访问页：支持公开分享和带密码分享，可浏览分享目录/打开文件。
class ShareViewerPage extends ConsumerStatefulWidget {
  final Site site;
  final String shareId;
  final String? password;

  const ShareViewerPage({
    super.key,
    required this.site,
    required this.shareId,
    this.password,
  });

  @override
  ConsumerState<ShareViewerPage> createState() => _ShareViewerPageState();
}

class _ShareViewerPageState extends ConsumerState<ShareViewerPage> {
  late final Dio _dio = createDio();
  late final CloudreveApi _api =
      CloudreveApi(dio: _dio, site: widget.site, token: null);

  late String? _password;
  ShareLink? _info;
  bool _checking = true;
  bool _locked = false;
  String? _fatalError;

  List<FileItem> _files = [];
  bool _loadingFiles = false;
  String? _loadError;
  int _fileLoadSeq = 0;

  /// 浏览状态（路径 / 视图 / 选择），由 [shareFileBrowserProvider] 持有。
  FileBrowserState get _browse => ref.read(shareFileBrowserProvider);

  FileBrowserController get _browseCtrl =>
      ref.read(shareFileBrowserProvider.notifier);

  /// 分享内的相对路径（根为空串）。
  String get _sharePath => _browse.pathSegments.join('/');

  bool get _isSelectionActive => _browse.selectedPaths.isNotEmpty;

  final GlobalKey _viewButtonKey = GlobalKey();

  /// 工具栏「排序」按钮，作为排序菜单的锚点。
  final GlobalKey _sortButtonKey = GlobalKey();

  /// 工具栏「更多」按钮，作为更多菜单的锚点。
  final GlobalKey _moreButtonKey = GlobalKey();

  /// 是否正在保存分享快捷方式。
  bool _savingShortcut = false;

  /// 多选时「更多操作」按钮，作为操作菜单的锚点。
  final GlobalKey _selectionMoreKey = GlobalKey();

  /// 分享页多选可用的操作（只读分享：下载 + 全选 / 反选）。
  static const List<FileOperation> _selectionOperations = [
    FileOperation.download,
    FileOperation.selectAll,
    FileOperation.invert,
  ];

  @override
  void initState() {
    super.initState();
    _password = widget.password;
    // provider 是全局的，每次进入都从分享根目录开始（顺带清空上次的选择）。
    // 放到微任务里，避免在构建期间修改 provider 触发 setState 报错。
    Future.microtask(() {
      if (mounted) {
        ref.read(shareFileBrowserProvider.notifier).setPath(const []);
      }
    });
    _loadInfo();
  }

  @override
  void dispose() {
    _dio.close(force: true);
    super.dispose();
  }

  Future<void> _loadInfo() async {
    setState(() {
      _checking = true;
      _fatalError = null;
      _locked = false;
    });
    try {
      final info = await _api.getShareInfo(
        widget.shareId,
        password: _password,
      );
      if (!mounted) return;
      if (info.unlocked || info.expired) {
        setState(() {
          _info = info;
          _locked = false;
          _checking = false;
        });
        if (info.expired) {
          _fatalError = tr('该分享链接已失效');
          setState(() {});
        } else {
          await _loadFiles();
        }
      } else {
        setState(() {
          _info = info;
          _locked = true;
          _checking = false;
        });
      }
    } catch (e) {
      print('[ShareViewerPage] 获取分享信息失败: $e');
      if (!mounted) return;
      setState(() {
        _checking = false;
        _fatalError =
            e is ApiException ? tr('分享失效或链接不存在') : tr('无法打开分享链接，请检查链接或网络');
      });
    }
  }

  Future<void> _submitPassword(String password) async {
    final pwd = password.trim();
    if (pwd.isEmpty) return;
    setState(() {
      _checking = true;
      _loadError = null;
    });
    try {
      final info = await _api.getShareInfo(widget.shareId, password: pwd);
      if (!mounted) return;
      if (info.expired) {
        setState(() {
          _password = pwd;
          _info = info;
          _locked = false;
          _checking = false;
          _fatalError = tr('该分享链接已失效');
        });
      } else if (info.unlocked) {
        setState(() {
          _password = pwd;
          _info = info;
          _locked = false;
          _checking = false;
        });
        await _loadFiles();
      } else {
        setState(() {
          _password = pwd;
          _info = info;
          _locked = true;
          _checking = false;
          _loadError = tr('密码错误，请重试');
        });
      }
    } catch (e) {
      print('[ShareViewerPage] 校验分享密码失败: $e');
      if (!mounted) return;
      setState(() {
        _checking = false;
        _loadError = tr('密码校验失败，请重试');
      });
    }
  }

  Future<void> _loadFiles() async {
    if (!mounted) return;
    final seq = ++_fileLoadSeq;
    setState(() {
      _loadingFiles = true;
      _loadError = null;
    });
    try {
      final uri =
          shareUri(widget.shareId, password: _password, path: _sharePath);
      final opt = sortOptionFor(_browse.sortKey);
      final listing = await _api.listFiles(
        uri,
        pageSize: _browse.pageSize,
        orderBy: opt?.orderBy,
        orderDirection: opt?.orderDirection,
      );
      if (!mounted || seq != _fileLoadSeq) return;
      setState(() {
        _files = listing.files;
        _loadingFiles = false;
      });
    } catch (e) {
      print('[ShareViewerPage] 获取分享文件列表失败: $e');
      if (!mounted || seq != _fileLoadSeq) return;
      setState(() {
        _loadingFiles = false;
        _loadError = tr('加载文件列表失败');
      });
    }
  }

  void _refresh() {
    if (_locked || _fatalError != null) return;
    _loadFiles();
  }

  void _openViewPanel() {
    showAppPopup<void>(
      context: context,
      anchorKey: _viewButtonKey,
      placement: AppPopupPlacement.below,
      builder: (_) => ViewPanel(
        initialViewMode: _browse.viewMode,
        initialThumbnails: _browse.thumbnails,
        initialPageSize: _browse.pageSize,
        onViewModeChanged: _browseCtrl.setViewMode,
        onThumbnailsChanged: _browseCtrl.setThumbnails,
        onPageSizeChanged: (v) {
          _browseCtrl.setPageSize(v);
          _loadFiles();
        },
      ),
    );
  }

  void _openSortMenu() {
    showSortMenu(
      context,
      anchorKey: _sortButtonKey,
      selected: _browse.sortKey,
      onSelected: (key) {
        _browseCtrl.setSortKey(key);
        _loadFiles();
      },
    );
  }

  /// 分享页「更多」菜单：刷新、保存快捷方式与选择操作。
  Future<void> _openMoreMenu() async {
    await showAppPopup<void>(
      context: context,
      anchorKey: _moreButtonKey,
      builder: (popupContext) {
        void run(VoidCallback action) {
          Navigator.of(popupContext).pop();
          action();
        }

        return AppPopup(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PopupItem(
                icon: Icons.refresh,
                label: tr('刷新'),
                onTap: () => run(_refresh),
              ),
              PopupItem(
                icon: Icons.bookmark_add_outlined,
                label: tr('保存分享为快捷方式'),
                onTap: () => run(_saveShareShortcut),
              ),
              Divider(height: 1, color: context.appColors.border),
              PopupItem(
                icon: Icons.select_all,
                label: tr('全选'),
                onTap: () => run(() => _browseCtrl.selectAll(_files)),
              ),
              PopupItem(
                icon: Icons.deselect,
                label: tr('取消选择'),
                onTap: () => run(_clearSelection),
              ),
              PopupItem(
                icon: Icons.flip_to_back,
                label: tr('反选'),
                onTap: () => run(() => _browseCtrl.invertSelection(_files)),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 把当前分享保存为「我的文件」里的快捷方式。
  Future<void> _saveShareShortcut() async {
    if (_savingShortcut) return;
    final info = _info;
    if (info == null) return;

    final site = ref.read(currentSiteProvider);
    final auth = ref.read(authProvider);
    if (site == null || !auth.isLoggedIn) {
      _toast(tr('请先登录后再保存分享'));
      return;
    }
    if (site.id != widget.site.id) {
      _toast(tr('只能保存当前站点的分享'));
      return;
    }

    final api = ref.read(apiProvider);
    setState(() => _savingShortcut = true);
    final selection = await showCloudFolderPicker(
      context,
      title: tr('创建快捷方式'),
      confirmLabel: tr('确定'),
      api: api,
    );
    if (!mounted) return;
    if (selection == null) {
      setState(() => _savingShortcut = false);
      return;
    }

    final redirect = shareRootUri(widget.shareId, password: _password);
    final baseName = info.name.trim().isEmpty ? tr('分享') : info.name.trim();
    try {
      var saved = false;
      for (var i = 0; i < 20 && !saved; i++) {
        final name = i == 0 ? baseName : '$baseName ($i)';
        try {
          await api.createShareShortcut(
            name: name,
            redirectUri: redirect,
            destinationPath: selection.path,
            ownerId: info.ownerId,
            isFolder: info.isFolder,
          );
          saved = true;
        } on ApiException catch (e) {
          // 同名快捷方式已存在时自动追加序号重试。
          if ((e.code == ApiException.objectExists || e.code == 409) &&
              i < 19) {
            continue;
          }
          rethrow;
        }
      }
      if (!mounted) return;
      ref.invalidate(sharedWithMeProvider);
      ref.invalidate(directoryProvider(const DirectoryQuery('/')));
      final folder = selection.folder;
      if (folder != null) {
        ref.invalidate(
          directoryProvider(DirectoryQuery(folder.relativePath)),
        );
      }
      final targetName =
          selection.name.trim().isEmpty ? tr('我的文件') : selection.name.trim();
      _toast(tr('已保存到「{name}」', args: {'name': targetName}));
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : '$e';
      _toast(tr('保存失败：{error}', args: {'error': message}));
    } finally {
      if (mounted) setState(() => _savingShortcut = false);
    }
  }

  void _enter(FileItem folder) {
    _browseCtrl.enter(folder.name);
    setState(() => _files = []);
    _loadFiles();
  }

  /// 面包屑跳转：0 = 根，i = 保留前 i 段。
  void _navigateToDepth(int depth) {
    _browseCtrl.setPath(_browse.pathSegments.take(depth).toList());
    setState(() => _files = []);
    _loadFiles();
  }

  /// 返回上一级目录（分享根目录是空路径）。
  void _goUp() {
    final segments = _browse.pathSegments;
    if (segments.isEmpty) return;
    _navigateToDepth(segments.length - 1);
  }

  /// 返回：多选时先取消选择；子目录回上一级；只有到了分享根目录才关闭页面。
  void _handleBack() {
    if (_isSelectionActive) {
      _clearSelection();
      return;
    }
    if (_browse.isRoot) {
      Navigator.of(context).pop();
      return;
    }
    _goUp();
  }

  void _toggleSelect(FileItem file) => _browseCtrl.toggleSelect(file.path);

  void _clearSelection() => _browseCtrl.clearSelection();

  /// 多选操作菜单：下载选中项 / 全选 / 反选。
  void _openSelectionMenu() {
    showFileOperations(
      context,
      anchorKey: _selectionMoreKey,
      operations: _selectionOperations,
      onAction: _handleSelectionOperation,
    );
  }

  void _handleSelectionOperation(FileOperation operation) {
    switch (operation) {
      case FileOperation.download:
        _downloadSelected();
      case FileOperation.selectAll:
        _browseCtrl.selectAll(_files);
      case FileOperation.invert:
        _browseCtrl.invertSelection(_files);
      default:
        break;
    }
  }

  Future<void> _downloadSelected() async {
    final selected =
        _files.where((f) => _browse.selectedPaths.contains(f.path)).toList();
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
          .enqueueCloudreveFiles(_api, files);
      if (!mounted) return;
      if (count > 0) {
        _clearSelection();
        _toastWithDownloadsAction(
            tr('已加入下载队列：{count} 个任务', args: {'count': count}));
      } else {
        _toast(tr('获取下载链接失败'));
      }
    } catch (e) {
      print('[ShareViewerPage] 加入下载队列失败: $e');
      if (mounted) _toast(tr('加入下载队列失败'));
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 打开下载任务页。
  void _openDownloads() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DownloadsPage()),
    );
  }

  /// 加入下载队列后的提示，带「查看」直达下载页。
  void _toastWithDownloadsAction(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        action: SnackBarAction(label: tr('查看'), onPressed: _openDownloads),
      ),
    );
  }

  void _open(FileItem file) {
    if (file.isFolder) {
      _enter(file);
      return;
    }
    if (isImage(file)) {
      final images = _files.where(isImage).toList();
      final index = images.indexWhere((f) => f.path == file.path);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ImageViewer(
            images: images.isEmpty ? [file] : images,
            initialIndex: index < 0 ? 0 : index,
            api: _api,
          ),
        ),
      );
    } else if (isVideo(file)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoPlayerViewer(file: file, api: _api),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        builder: (_) => FileInfoSheet(file: file, api: _api),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 订阅浏览状态：多选、视图切换、路径变化后都需要重建。
    final browse = ref.watch(shareFileBrowserProvider);
    final colors = context.appColors;
    final atRoot = browse.isRoot;
    final selecting = browse.selectedPaths.isNotEmpty;
    // 根目录且没在多选时才允许关闭页面，其余情况交给 _handleBack 逐级处理。
    final canClose = atRoot && !selecting;
    return PopScope(
      canPop: canClose,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: colors.contentBg,
        appBar: AppBar(
          backgroundColor: colors.headerBg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            tooltip: selecting
                ? tr('取消选择')
                : atRoot
                    ? tr('关闭')
                    : tr('返回上一级'),
            icon: Icon(
              selecting || atRoot ? Icons.close : Icons.arrow_back,
              size: selecting || atRoot ? 18 : 20,
              color: colors.textSecondary,
            ),
            onPressed: _handleBack,
          ),
          title: Text(
            _info?.name ?? tr('分享'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colors.textPrimary,
            ),
          ),
          actions: [
            if (selecting)
              SelectionActions(
                count: browse.selectedPaths.length,
                onClear: _clearSelection,
                onMore: _openSelectionMenu,
                moreButtonKey: _selectionMoreKey,
              )
            else ...[
              IconButton(
                tooltip: tr('下载任务'),
                icon: Icon(Icons.download_outlined,
                    size: 20, color: colors.textSecondary),
                onPressed: _openDownloads,
              ),
              const SizedBox(width: 8),
            ],
          ],
          bottom: !_checking && !_locked && _fatalError == null
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(52),
                  child: _buildToolbar(context),
                )
              : null,
        ),
        body: _buildBody(context),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Breadcrumb(
              segments: _browse.pathSegments,
              rootLabel: tr('分享根目录'),
              rootIcon: Icons.folder_shared_outlined,
              onNavigate: _navigateToDepth,
            ),
          ),
          const SizedBox(width: 12),
          ToolbarActionGroup(
            actions: [
              ToolbarActionItem(
                key: _viewButtonKey,
                icon: Icons.grid_view_outlined,
                tooltip: tr('切换视图'),
                onTap: _openViewPanel,
              ),
              ToolbarActionItem(
                key: _sortButtonKey,
                icon: Icons.swap_vert,
                tooltip: tr('排序'),
                onTap: _openSortMenu,
              ),
              ToolbarActionItem(
                key: _moreButtonKey,
                icon: Icons.more_horiz,
                tooltip: tr('更多'),
                onTap: _openMoreMenu,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final colors = context.appColors;
    if (_checking) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_fatalError != null) {
      return ErrorView(
        message: _fatalError!,
        icon: Icons.link_off_outlined,
      );
    }
    if (_locked) {
      return SharePasswordView(
        shareName: _info?.name ?? tr('分享内容'),
        initialPassword: _password ?? '',
        errorText: _loadError,
        loading: _checking,
        onSubmit: _submitPassword,
      );
    }
    if (_loadingFiles && _files.isEmpty && _loadError == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null && _files.isEmpty) {
      return ErrorView(
        message: _loadError!,
        icon: Icons.link_off_outlined,
        onRetry: _loadFiles,
      );
    }
    if (_files.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_outlined, size: 48, color: colors.textMuted),
            const SizedBox(height: 8),
            Text(tr('此分享没有可显示的内容'),
                style: TextStyle(fontSize: 14, color: colors.textSecondary)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 刷新时给一条细进度条，避免「点了没反应」的错觉。
        if (_loadingFiles) const LinearProgressIndicator(minHeight: 2),
        Expanded(child: _buildListing()),
      ],
    );
  }

  Widget _buildListing() {
    final browse = _browse;
    return FileBrowserView(
      files: _files,
      viewMode: browse.viewMode,
      showThumbnails: browse.thumbnails,
      selectedPaths: browse.selectedPaths,
      onOpen: _open,
      onSelect: _toggleSelect,
      api: _api,
      showChevron: true,
    );
  }
}
