import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/network/cloudreve_api.dart';
import '../../core/theme/app_colors.dart';
import '../../models/file_item.dart';
import '../../providers/api_provider.dart';
import '../common/cloud_folder_tree.dart';

/// 文件夹选择结果。
///
/// 默认根目录用 `path = '/'`、`isRoot = true` 表示，此时 [folder] 为 null；
/// 自定义 `rootPath` 时 [path] 为传入的根路径。
class CloudFolderSelection {
  final String path;
  final String name;
  final bool isRoot;
  final FileItem? folder;

  const CloudFolderSelection({
    required this.path,
    required this.name,
    this.isRoot = false,
    this.folder,
  });
}

/// 打开通用云端文件夹选择页，返回用户选中的文件夹；取消时返回 null。
///
/// 默认从「我的文件」根目录开始，按需加载每一层子文件夹，适配移动端。
/// 分享等场景可以传入自己的 [api]、[rootPath] 和 [rootName]。
Future<CloudFolderSelection?> showCloudFolderPicker(
  BuildContext context, {
  String? title,
  String? confirmLabel,
  CloudreveApi? api,
  String rootPath = '/',
  String? rootName,
}) {
  return Navigator.of(context).push<CloudFolderSelection>(
    MaterialPageRoute(
      builder: (_) => CloudFolderPickerPage(
        title: title,
        confirmLabel: confirmLabel,
        api: api,
        rootPath: rootPath,
        rootName: rootName,
      ),
    ),
  );
}

/// 通用云端文件夹选择页。
///
/// 结构：顶部标题栏 + 返回按钮，中间为按需加载的目录树，底部固定显示当前
/// 选中的文件夹和「确定」按钮。根目录「我的文件」默认选中并展开。
class CloudFolderPickerPage extends ConsumerStatefulWidget {
  /// 页面标题，默认「选择文件夹」。
  final String? title;

  /// 确认按钮文案，默认「确定」。
  final String? confirmLabel;

  /// 自定义 API；为空时使用当前站点 API。
  final CloudreveApi? api;

  /// 树根路径，默认「我的文件」根目录 `/`；分享场景可传分享根目录 URI。
  final String rootPath;

  /// 树根显示名称，默认「我的文件」。
  final String? rootName;

  const CloudFolderPickerPage({
    super.key,
    this.title,
    this.confirmLabel,
    this.api,
    this.rootPath = '/',
    this.rootName,
  });

  @override
  ConsumerState<CloudFolderPickerPage> createState() =>
      _CloudFolderPickerPageState();
}

class _CloudFolderPickerPageState extends ConsumerState<CloudFolderPickerPage> {
  /// 内容最大宽度，平板 / 桌面上避免目录树铺得过宽。
  static const double _maxContentWidth = 640;

  late final CloudreveApi _api;

  /// 当前选中的文件夹；null 表示根目录「我的文件」。
  FileItem? _selected;

  /// 防止确认 / 返回按钮被连点导致重复 pop。
  bool _popping = false;

  /// 已加载的子目录，key 为父目录 path。
  final Map<String, List<FileItem>> _children = {};

  /// 正在加载的目录 path。
  final Set<String> _loading = {};

  /// 加载失败的目录 path。
  final Set<String> _errors = {};

  /// 已展开的目录 path。
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? ref.read(apiProvider);
    _expanded.add(widget.rootPath);
    _loadChildren(widget.rootPath, initial: true);
  }

  /// 加载 [path] 下的子文件夹；同一目录不会重复请求。
  Future<void> _loadChildren(String path, {bool initial = false}) async {
    if (_children.containsKey(path) || _loading.contains(path)) return;
    if (initial) {
      _loading.add(path);
    } else {
      setState(() {
        _errors.remove(path);
        _loading.add(path);
      });
    }
    try {
      final listing = await _api.listFiles(path, pageSize: 500);
      if (!mounted) return;
      setState(() {
        _children[path] =
            listing.files.where((f) => f.isFolder).toList(growable: false);
        _loading.remove(path);
        _errors.remove(path);
      });
    } catch (e) {
      debugPrint('[CloudFolderPicker] 加载文件夹失败: $path -> $e');
      if (!mounted) return;
      setState(() {
        _loading.remove(path);
        _errors.add(path);
      });
    }
  }

  void _select(CloudFolderTreeEntry entry) {
    if (entry.kind != CloudFolderTreeEntryKind.folder) return;
    setState(() => _selected = entry.folder);
  }

  void _toggle(CloudFolderTreeEntry entry) {
    if (entry.kind != CloudFolderTreeEntryKind.folder) return;
    final path = entry.id;
    if (_expanded.contains(path)) {
      setState(() => _expanded.remove(path));
      return;
    }
    setState(() => _expanded.add(path));
    if (!_children.containsKey(path) &&
        !_loading.contains(path) &&
        !_errors.contains(path)) {
      _loadChildren(path);
    }
  }

  void _retry(CloudFolderTreeEntry entry) {
    if (entry.kind != CloudFolderTreeEntryKind.error) return;
    setState(() => _errors.remove(entry.id));
    _loadChildren(entry.id);
  }

  /// 把当前展开状态展开成扁平的可见节点列表，交给纯展示的 [CloudFolderTree]。
  List<CloudFolderTreeEntry> _buildEntries(String rootName) {
    final rootExpanded = _expanded.contains(widget.rootPath);
    final entries = <CloudFolderTreeEntry>[
      CloudFolderTreeEntry.folder(
        id: widget.rootPath,
        label: rootName,
        depth: 0,
        isRoot: true,
        expanded: rootExpanded,
        selected: _selected == null,
      ),
    ];
    if (rootExpanded) {
      _appendChildren(entries, widget.rootPath, 1);
    }
    return entries;
  }

  void _appendChildren(
    List<CloudFolderTreeEntry> entries,
    String path,
    int depth,
  ) {
    if (_loading.contains(path)) {
      entries.add(CloudFolderTreeEntry.loading(id: path, depth: depth));
      return;
    }
    if (_errors.contains(path)) {
      entries.add(CloudFolderTreeEntry.error(id: path, depth: depth));
      return;
    }
    final children = _children[path];
    if (children == null) {
      entries.add(CloudFolderTreeEntry.loading(id: path, depth: depth));
      return;
    }
    if (children.isEmpty) {
      entries.add(CloudFolderTreeEntry.empty(id: path, depth: depth));
      return;
    }
    for (final folder in children) {
      final expanded = _expanded.contains(folder.path);
      entries.add(CloudFolderTreeEntry.folder(
        id: folder.path,
        label: folder.name,
        depth: depth,
        expanded: expanded,
        selected: _selected?.path == folder.path,
        folder: folder,
      ));
      if (expanded) {
        _appendChildren(entries, folder.path, depth + 1);
      }
    }
  }

  void _close() {
    if (_popping) return;
    _popping = true;
    Navigator.of(context).maybePop();
  }

  void _confirm() {
    if (_popping) return;
    _popping = true;
    final l10n = AppLocalizations.of(context);
    final selected = _selected;
    final rootName = widget.rootName ?? l10n.t('我的文件');
    Navigator.of(context).pop(
      CloudFolderSelection(
        path: selected?.path ?? widget.rootPath,
        name: selected == null
            ? rootName
            : (selected.name.trim().isEmpty ? selected.path : selected.name),
        isRoot: selected == null,
        folder: selected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final title = widget.title ?? l10n.t('选择文件夹');

    return Scaffold(
      backgroundColor: colors.contentBg,
      appBar: AppBar(
        backgroundColor: colors.headerBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          key: const ValueKey('picker-back'),
          tooltip: l10n.t('返回'),
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: _close,
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: colors.textPrimary),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                child: _buildTree(l10n),
              ),
            ),
          ),
          _buildFooter(l10n, colors),
        ],
      ),
    );
  }

  Widget _buildTree(AppLocalizations l10n) {
    return CloudFolderTree(
      entries: _buildEntries(widget.rootName ?? l10n.t('我的文件')),
      onSelect: _select,
      onToggle: _toggle,
      onRetry: _retry,
    );
  }

  Widget _buildFooter(AppLocalizations l10n, AppColors colors) {
    final selected = _selected;
    final rootName = widget.rootName ?? l10n.t('我的文件');
    final name = selected == null
        ? rootName
        : (selected.name.trim().isEmpty ? selected.path : selected.name);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.contentBg,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      key: const ValueKey('picker-selected'),
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        border: Border.all(color: colors.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            selected == null
                                ? Icons.home_outlined
                                : Icons.folder_outlined,
                            size: 18,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  key: const ValueKey('picker-confirm'),
                  onPressed: _confirm,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: Text(widget.confirmLabel ?? l10n.t('确定')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
