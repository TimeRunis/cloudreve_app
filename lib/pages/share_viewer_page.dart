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
import '../widgets/file_card.dart';
import '../widgets/file_icon.dart';
import '../widgets/file_info_sheet.dart';
import '../widgets/image_viewer.dart';
import '../widgets/video_player_viewer.dart';
import '../widgets/view_panel.dart';

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

  String _path = '';
  List<FileItem> _files = [];
  bool _loadingFiles = false;
  String? _loadError;
  int _fileLoadSeq = 0;

  final Set<String> _selected = {};

  bool get _isSelectionActive => _selected.isNotEmpty;

  // 与主页一致的视图偏好。
  String _viewMode = 'grid'; // grid | list | gallery
  bool _thumbnails = true;
  int _pageSize = 100;

  final GlobalKey _viewButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _password = widget.password;
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
        _fatalError = e is ApiException
            ? '分享失效或链接不存在'
            : '无法打开分享链接，请检查链接或网络';
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
      final uri = shareUri(widget.shareId,
          password: _password, path: _path);
      final listing = await _api.listFiles(uri, pageSize: _pageSize);
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
    final box =
        _viewButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final size = MediaQuery.of(context).size;
    final fallbackTop = MediaQuery.of(context).padding.top + kToolbarHeight + 52;
    final anchorTop = box == null
        ? fallbackTop
        : box.localToGlobal(Offset.zero).dy + box.size.height + 4;
    final anchorRight = box == null
        ? 16.0
        : size.width - box.localToGlobal(Offset.zero).dx - box.size.width;
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
              top: anchorTop,
              right: anchorRight,
              child: ViewPanel(
                initialViewMode: _viewMode,
                initialThumbnails: _thumbnails,
                initialPageSize: _pageSize,
                onViewModeChanged: (v) => setState(() => _viewMode = v),
                onThumbnailsChanged: (v) => setState(() => _thumbnails = v),
                onPageSizeChanged: (v) {
                  setState(() => _pageSize = v);
                  _loadFiles();
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _enter(FileItem folder) {
    setState(() {
      _path = _path.isEmpty ? folder.name : '$_path/${folder.name}';
      _files = [];
      _selected.clear();
    });
    _loadFiles();
  }

  void _goBack() {
    final segments = _path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return;
    setState(() {
      _path = segments.isEmpty ? '' : segments.join('/');
      _files = [];
      _selected.clear();
    });
    _loadFiles();
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

  Future<void> _downloadSelected() async {
    final selectedFiles = _files
        .where((f) => _selected.contains(f.path) && !f.isFolder)
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
      _toast(count > 0 ? '已加入下载队列：$count 个任务' : '获取下载链接失败');
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
      _toast(count > 0 ? '已加入下载队列：$count 个任务' : '获取下载链接失败');
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
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.contentBg,
      appBar: AppBar(
        backgroundColor: colors.headerBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: '返回',
          icon: Icon(Icons.close,
              size: 18, color: colors.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
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
        actions: const [SizedBox(width: 8)],
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
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final colors = context.appColors;
    final segments = _path.split('/').where((s) => s.isNotEmpty).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: colors.toolbarBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _path.isEmpty ? null : _goBack,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      if (_path.isNotEmpty) ...[
                        Icon(Icons.arrow_back,
                            size: 18, color: colors.textSecondary),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          segments.isEmpty ? '分享根目录' : segments.join(' / '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: colors.toolbarBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: 40,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ToolbarAction(
                    key: _viewButtonKey,
                    icon: Icons.grid_view_outlined,
                    tooltip: '切换视图',
                    onTap: _openViewPanel,
                  ),
                  _ToolbarAction(
                    icon: Icons.file_download_outlined,
                    tooltip: '下载',
                    onTap: _handleDownloadTap,
                  ),
                  _ToolbarAction(
                    icon: Icons.refresh,
                    tooltip: '刷新',
                    onTap: _refresh,
                    last: true,
                  ),
                ],
              ),
            ),
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
      return _ErrorView(message: _fatalError!);
    }
    if (_locked) {
      return _PasswordView(
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
      return _ErrorView(message: _loadError!, onRetry: _loadFiles);
    }
    if (_files.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_outlined,
                size: 48, color: colors.textMuted),
            const SizedBox(height: 8),
            Text('此分享没有可显示的内容',
                style: TextStyle(fontSize: 14, color: colors.textSecondary)),
          ],
        ),
      );
    }

    return _buildListing();
  }

  Widget _buildSelectionBar(BuildContext context) {
    final colors = context.appColors;
    return Container(
      color: colors.headerBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            '已选择 ${_selected.length} 项',
            style: TextStyle(
                fontSize: 14, color: colors.textPrimary),
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
            label: Text('下载 (${_selected.length})'),
          ),
        ],
      ),
    );
  }

  Widget _buildListing() {
    final colors = context.appColors;
    final files = _files;
    final folders = files.where((f) => f.isFolder).toList();
    final fileItems = files.where((f) => !f.isFolder).toList();

    if (_viewMode == 'list') {
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: files.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: colors.border),
        itemBuilder: (context, i) {
          final file = files[i];
          final isSelected = _selected.contains(file.path);
          return ListTile(
            onTap: () => _open(file),
            leading: IconButton(
              tooltip: '选择',
              icon: isSelected
                  ? const SelectionCheck(size: 22)
                  : Icon(fileIcon(file),
                      color: fileIconColor(context, file), size: 28),
              onPressed: () => _toggleSelect(file),
            ),
            title: Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: colors.textPrimary),
            ),
            subtitle: Text(file.isFolder ? '文件夹' : formatSize(file.size),
                style: TextStyle(fontSize: 12, color: colors.textMuted)),
            trailing: Icon(Icons.chevron_right,
                size: 18, color: colors.textFaint),
          );
        },
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (folders.isNotEmpty) ...[
          const SizedBox(height: 16),
          _ShareSectionTitle('文件夹'),
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
              return _ShareFolderCard(
                folder: folder,
                isSelected: _selected.contains(folder.path),
                onOpen: () => _open(folder),
                onLongPress: () => _toggleSelect(folder),
              );
            },
          ),
        ],
        if (fileItems.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _ShareSectionTitle('文件'),
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
                api: _api,
              );
            },
          ),
        ],
      ],
    );
  }
}

class _ShareSectionTitle extends StatelessWidget {
  final String text;

  const _ShareSectionTitle(this.text);

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

/// 与主页文件夹卡片一致的横向卡片。
class _ShareFolderCard extends StatelessWidget {
  final FileItem folder;
  final bool isSelected;
  final VoidCallback onOpen;
  final VoidCallback onLongPress;

  const _ShareFolderCard({
    required this.folder,
    required this.isSelected,
    required this.onOpen,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.surfaceMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                isSelected
                    ? const SelectionCheck(size: 18)
                    : Icon(Icons.folder,
                        size: 18, color: colors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      folder.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14, color: colors.textPrimary),
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

class _ToolbarAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool last;

  const _ToolbarAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: last
                ? null
                : Border(
                    right: BorderSide(color: colors.toolbarBorder)),
          ),
          child: Icon(icon, size: 18, color: colors.textSecondary),
        ),
      ),
    );
  }
}

class _PasswordView extends StatefulWidget {
  final String shareName;
  final String initialPassword;
  final String? errorText;
  final bool loading;
  final ValueChanged<String> onSubmit;

  const _PasswordView({
    required this.shareName,
    required this.initialPassword,
    this.errorText,
    this.loading = false,
    required this.onSubmit,
  });

  @override
  State<_PasswordView> createState() => _PasswordViewState();
}

class _PasswordViewState extends State<_PasswordView> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialPassword);
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_outline,
                    size: 28, color: colors.textSecondary),
              ),
              const SizedBox(height: 16),
              Text(
                '该分享已加密',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.shareName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: colors.textMuted),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                obscureText: _obscure,
                enabled: !widget.loading,
                decoration: InputDecoration(
                  hintText: '请输入访问密码',
                  prefixIcon: Icon(Icons.password,
                      size: 18, color: colors.textMuted),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 18,
                      color: colors.textMuted,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  filled: true,
                  fillColor: colors.surfaceMuted,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              if (widget.errorText != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.errorText!,
                    style: TextStyle(
                        fontSize: 12, color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: widget.loading ? null : _submit,
                  child: Text(widget.loading ? '校验中…' : '进入分享'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmit(text);
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorView({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link_off_outlined, size: 48, color: colors.textMuted),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: colors.textSecondary),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
            ),
          ],
        ],
      ),
    );
  }
}