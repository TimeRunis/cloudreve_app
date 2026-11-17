import 'package:flutter/material.dart';

import '../../core/network/cloudreve_api.dart';
import '../../models/file_item.dart';
import '../common/section_title.dart';
import '../file/file_card.dart';
import '../file/file_list_tile.dart';
import '../file/folder_card.dart';

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
            children: const [
              SizedBox(height: 80),
              Center(child: Text('此目录为空')),
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (folders.isNotEmpty) ...[
          const SizedBox(height: 16),
          const SectionTitle.content('文件夹'),
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
          const SectionTitle.content('文件'),
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
  }
}
