import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/file_item.dart';

/// 与数据源无关的文件浏览状态。
///
/// 主页与分享页各持一份实例（见 [homeFileBrowserProvider]），因此路径用
/// 「层级列表」表示，由各页自己换算成后端需要的路径格式：
/// - 主页：`/` + segments.join('/')
/// - 分享页：segments.join('/')（根为空串）
class FileBrowserState {
  /// 当前路径层级（原样保存，渲染时再解码）。
  final List<String> pathSegments;

  /// grid | list
  final String viewMode;
  final bool thumbnails;
  final int pageSize;

  /// 排序 key；空串表示不指定排序（沿用服务端默认）。
  final String sortKey;

  /// 已选中的文件 path 集合。
  final Set<String> selectedPaths;

  const FileBrowserState({
    this.pathSegments = const [],
    this.viewMode = 'grid',
    this.thumbnails = true,
    this.pageSize = 50,
    this.sortKey = '',
    this.selectedPaths = const {},
  });

  bool get isRoot => pathSegments.isEmpty;

  FileBrowserState copyWith({
    List<String>? pathSegments,
    String? viewMode,
    bool? thumbnails,
    int? pageSize,
    String? sortKey,
    Set<String>? selectedPaths,
  }) {
    return FileBrowserState(
      pathSegments: pathSegments ?? this.pathSegments,
      viewMode: viewMode ?? this.viewMode,
      thumbnails: thumbnails ?? this.thumbnails,
      pageSize: pageSize ?? this.pageSize,
      sortKey: sortKey ?? this.sortKey,
      selectedPaths: selectedPaths ?? this.selectedPaths,
    );
  }
}

/// 浏览状态控制器：只负责状态变更，不碰任何数据源。
class FileBrowserController extends Notifier<FileBrowserState> {
  @override
  FileBrowserState build() => const FileBrowserState();

  /// 进入下一层目录。
  void enter(String name) {
    state = state.copyWith(
      pathSegments: [...state.pathSegments, name],
      selectedPaths: const {},
    );
  }

  /// 回到第 [depth] 层（0 = 根）。
  void goTo(int depth) {
    final target = depth.clamp(0, state.pathSegments.length);
    if (target == state.pathSegments.length) return;
    state = state.copyWith(
      pathSegments: state.pathSegments.sublist(0, target),
      selectedPaths: const {},
    );
  }

  /// 直接用整条路径替换（面包屑跳转、返回上级都会用到）。
  void setPath(List<String> segments) {
    state = state.copyWith(
      pathSegments: segments,
      selectedPaths: const {},
    );
  }

  void reset() {
    state = const FileBrowserState();
  }

  void setViewMode(String mode) => state = state.copyWith(viewMode: mode);

  void setThumbnails(bool value) => state = state.copyWith(thumbnails: value);

  void setPageSize(int value) => state = state.copyWith(pageSize: value);

  void setSortKey(String key) => state = state.copyWith(sortKey: key);

  void toggleSelect(String path) {
    final next = Set<String>.of(state.selectedPaths);
    if (!next.remove(path)) next.add(path);
    state = state.copyWith(selectedPaths: next);
  }

  void clearSelection() => state = state.copyWith(selectedPaths: const {});

  void selectAll(Iterable<FileItem> files) {
    state = state.copyWith(
      selectedPaths: files.map((f) => f.path).toSet(),
    );
  }

  void invertSelection(Iterable<FileItem> files) {
    final all = files.map((f) => f.path).toSet();
    state = state.copyWith(selectedPaths: all.difference(state.selectedPaths));
  }
}

/// 主页的浏览状态实例。
final homeFileBrowserProvider =
    NotifierProvider<FileBrowserController, FileBrowserState>(
  FileBrowserController.new,
);

/// 分享页的浏览状态实例（与主页互不影响）。
final shareFileBrowserProvider =
    NotifierProvider<FileBrowserController, FileBrowserState>(
  FileBrowserController.new,
);
