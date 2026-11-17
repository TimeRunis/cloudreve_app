import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../core/network/cloudreve_api.dart';
import '../core/theme/app_colors.dart';
import '../models/file_item.dart';
import '../models/share.dart';
import '../models/site.dart';
import '../providers/download_provider.dart';
import '../providers/file_browser_provider.dart';
import '../widgets/common/error_view.dart';
import '../widgets/common/toolbar_action_group.dart';
import '../widgets/file/file_icon.dart';
import '../widgets/file/view_panel.dart';
import '../widgets/file_browser/file_browser_view.dart';
import '../widgets/navigation/breadcrumb.dart';
import '../widgets/popup/app_popup.dart';
import '../widgets/popup/sort_popup.dart';
import '../widgets/share/share_password_view.dart';
import '../widgets/sheet/file_info_sheet.dart';
import '../widgets/viewer/image_viewer.dart';
import '../widgets/viewer/video_player_viewer.dart';
import 'downloads_page.dart';

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
          _fatalError = '该分享链接已失效';
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
        _fatalError = e is ApiException ? '分享失效或链接不存在' : '无法打开分享链接，请检查链接或网络';
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
          _fatalError = '该分享链接已失效';
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
          _loadError = '密码错误，请重试';
        });
      }
    } catch (e) {
      print('[ShareViewerPage] 校验分享密码失败: $e');
      if (!mounted) return;
      setState(() {
        _checking = false;
        _loadError = '密码校验失败，请重试';
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
        _loadError = '加载文件列表失败';
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

  Future<void> _downloadSelected() async {
    final selectedFiles = _files
        .where((f) => _browse.selectedPaths.contains(f.path) && !f.isFolder)
        .toList();
    if (selectedFiles.isEmpty) {
      _toast('文件夹打包下载暂不支持');
      return;
    }
    try {
      final count = await ref
          .read(downloadManagerProvider)
          .manager
          .enqueueCloudreveFiles(_api, selectedFiles);
      if (!mounted) return;
      if (count > 0) _clearSelection();
      if (count > 0) {
        _toastWithDownloadsAction('已加入下载队列：$count 个任务');
      } else {
        _toast('获取下载链接失败');
      }
    } catch (e) {
      print('[ShareViewerPage] 加入下载队列失败: $e');
      if (mounted) _toast('加入下载队列失败');
    }
  }

  Future<void> _downloadVisibleFiles() async {
    final files = _files.where((f) => !f.isFolder).toList();
    if (files.isEmpty) {
      _toast('当前目录没有可下载的文件');
      return;
    }
    try {
      final count = await ref
          .read(downloadManagerProvider)
          .manager
          .enqueueCloudreveFiles(_api, files);
      if (!mounted) return;
      if (count > 0) {
        _toastWithDownloadsAction('已加入下载队列：$count 个任务');
      } else {
        _toast('获取下载链接失败');
      }
    } catch (e) {
      print('[ShareViewerPage] 加入下载队列失败: $e');
      if (mounted) _toast('加入下载队列失败');
    }
  }

  void _handleDownloadTap() {
    if (_isSelectionActive) {
      _downloadSelected();
    } else {
      _downloadVisibleFiles();
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
        action: SnackBarAction(label: '查看', onPressed: _openDownloads),
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
                ? '取消选择'
                : atRoot
                    ? '关闭'
                    : '返回上一级',
            icon: Icon(
              selecting || atRoot ? Icons.close : Icons.arrow_back,
              size: selecting || atRoot ? 18 : 20,
              color: colors.textSecondary,
            ),
            onPressed: _handleBack,
          ),
          title: Text(
            _info?.name ?? '分享',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colors.textPrimary,
            ),
          ),
          actions: [
            IconButton(
              tooltip: '下载任务',
              icon: Icon(Icons.download_outlined,
                  size: 20, color: colors.textSecondary),
              onPressed: _openDownloads,
            ),
            const SizedBox(width: 8),
          ],
          bottom: !_checking && !_locked && _fatalError == null
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(52),
                  child: _isSelectionActive
                      ? _buildSelectionBar(context)
                      : _buildToolbar(context),
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
              rootLabel: '分享根目录',
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
                tooltip: '切换视图',
                onTap: _openViewPanel,
              ),
              ToolbarActionItem(
                key: _sortButtonKey,
                icon: Icons.swap_vert,
                tooltip: '排序',
                onTap: _openSortMenu,
              ),
              ToolbarActionItem(
                icon: Icons.file_download_outlined,
                tooltip: '下载',
                onTap: _handleDownloadTap,
              ),
              ToolbarActionItem(
                icon: Icons.refresh,
                tooltip: '刷新',
                onTap: _refresh,
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
        shareName: _info?.name ?? '分享内容',
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
            Text('此分享没有可显示的内容',
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

  Widget _buildSelectionBar(BuildContext context) {
    final colors = context.appColors;
    return Container(
      color: colors.headerBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            '已选择 ${_browse.selectedPaths.length} 项',
            style: TextStyle(fontSize: 14, color: colors.textPrimary),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _clearSelection,
            icon: const Icon(Icons.close, size: 18),
            label: const Text('取消选择'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _downloadSelected,
            icon: const Icon(Icons.file_download_outlined, size: 18),
            label: Text('下载 (${_browse.selectedPaths.length})'),
          ),
        ],
      ),
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
