import 'package:flutter/material.dart';

import '../../models/file_item.dart';
import '../file/file_icon.dart';

/// 文件列表行（列表视图）：左侧选择按钮 + 名称 + 大小。
class FileListTile extends StatelessWidget {
  final FileItem file;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onOpen;

  /// 是否处于多选状态：此时点击整行是切换选择，而不是打开。
  final bool selectionMode;

  /// 右侧是否显示「进入」箭头（分享页使用）。
  final bool showChevron;

  const FileListTile({
    super.key,
    required this.file,
    required this.isSelected,
    required this.onSelect,
    required this.onOpen,
    this.selectionMode = false,
    this.showChevron = false,
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
      trailing: showChevron && !selectionMode
          ? Icon(Icons.chevron_right,
              size: 18, color: Theme.of(context).colorScheme.outline)
          : null,
      onTap: selectionMode ? onSelect : onOpen,
    );
  }
}
