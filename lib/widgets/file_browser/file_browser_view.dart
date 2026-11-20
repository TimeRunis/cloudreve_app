import 'package:flutter/material.dart';

import '../../core/network/cloudreve_api.dart';
import '../../models/file_item.dart';
import '../common/section_title.dart';
import '../file/file_card.dart';
import '../file/file_list_tile.dart';
import '../file/folder_card.dart';
import '../../core/i18n/app_localizations.dart';

/// 与数据源无关的文件浏览视图。
///
/// 负责三种渲染：列表视图、文件夹网格 + 文件网格。主页与分享页共用，
/// 分享页通过 [api] 传入带鉴权的接口用于缩略图。
class FileBrowserView extends StatelessWidget {
  final List<FileItem> files;

  /// grid | list
  final String viewMode;
  final bool showThumbnails;
  final Set<String> selectedPaths;
  final ValueChanged<FileItem> onOpen;
  final ValueChanged<FileItem> onSelect;

  /// 分享页缩略图需要带鉴权的 api；主页不传（走默认 provider）。
  final CloudreveApi? api;

  /// 列表视图是否显示右侧箭头。
  final bool showChevron;

  /// 空列表占位，默认「此目录为空」。
  final Widget? empty;

  /// 宽屏断点：可用宽度 ≥600 一行 3 张，≥1000（超宽屏）一行 4 张，
  /// 手机竖屏仍是 2 张。
  static const double _wideBreakpoint = 600;
  static const double _ultraWideBreakpoint = 1000;

  /// 宽屏下卡片的目标高度：只增加列数，不把卡片纵向拉高。
  static const double _wideFolderHeight = 56;
  static const double _wideFileHeight = 230;

  /// 按可用宽度决定网格列数。
  static int _columnsFor(double width) {
    if (width >= _ultraWideBreakpoint) return 4;
    if (width >= _wideBreakpoint) return 3;
    return 2;
  }

  const FileBrowserView({
    super.key,
    required this.files,
    required this.viewMode,
    required this.showThumbnails,
    required this.selectedPaths,
    required this.onOpen,
    required this.onSelect,
    this.api,
    this.showChevron = false,
    this.empty,
  });

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return empty ??
          ListView(
            children: [
              SizedBox(height: 80),
              Center(child: Text(tr('此目录为空'))),
            ],
          );
    }

    // 已有选中项即为多选状态：此时单击任意项都是切换选择，而不是打开。
    final selecting = selectedPaths.isNotEmpty;

    if (viewMode == 'list') {
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: files.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final file = files[i];
          return FileListTile(
            file: file,
            isSelected: selectedPaths.contains(file.path),
            selectionMode: selecting,
            showChevron: showChevron,
            onSelect: () => onSelect(file),
            onOpen: () => onOpen(file),
          );
        },
      );
    }

    final folders = files.where((f) => f.isFolder).toList();
    final fileItems = files.where((f) => !f.isFolder).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        // 宽屏一行 3 张、超宽屏 4 张；手机竖屏保持原来的 2 张。
        final columns = _columnsFor(constraints.maxWidth);
        const gap = 12.0;
        // ListView 左右各有 16 的内边距，扣掉后再算单张卡片宽度。
        final cardWidth =
            (constraints.maxWidth - 32 - gap * (columns - 1)) / columns;
        final folderRatio = columns == 2
            ? 3.0
            : (cardWidth / _wideFolderHeight).clamp(1.6, 8.0);
        final fileRatio =
            columns == 2 ? 0.9 : (cardWidth / _wideFileHeight).clamp(0.6, 3.0);
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            if (folders.isNotEmpty) ...[
              const SizedBox(height: 16),
              SectionTitle.content(tr('文件夹')),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: gap,
                  childAspectRatio: folderRatio,
                ),
                itemCount: folders.length,
                itemBuilder: (context, i) {
                  final folder = folders[i];
                  return FolderCard(
                    folder: folder,
                    isSelected: selectedPaths.contains(folder.path),
                    selectionMode: selecting,
                    onSelect: () => onSelect(folder),
                    onOpen: () => onOpen(folder),
                  );
                },
              ),
            ],
            if (fileItems.isNotEmpty) ...[
              const SizedBox(height: 24),
              SectionTitle.content(tr('文件')),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: gap,
                  childAspectRatio: fileRatio,
                ),
                itemCount: fileItems.length,
                itemBuilder: (context, i) {
                  final file = fileItems[i];
                  return FileCard(
                    file: file,
                    isSelected: selectedPaths.contains(file.path),
                    selectionMode: selecting,
                    showThumb: showThumbnails,
                    onSelect: () => onSelect(file),
                    onOpen: () => onOpen(file),
                    api: api,
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }
}
