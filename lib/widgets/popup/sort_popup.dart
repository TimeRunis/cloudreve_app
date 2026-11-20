import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'app_popup.dart';

/// 排序选项。
class SortOption {
  final String key;
  final String label;
  final String orderBy;
  final String orderDirection;

  const SortOption(this.key, this.label, this.orderBy, this.orderDirection);
}

/// 可用的排序项（对应 Cloudreve 的 order_by / order_direction）。
const sortOptions = [
  SortOption('name-asc', 'A-Z', 'name', 'asc'),
  SortOption('name-desc', 'Z-A', 'name', 'desc'),
  SortOption('size-asc', '最小', 'size', 'asc'),
  SortOption('size-desc', '最大', 'size', 'desc'),
  SortOption('updated_at-asc', '最早修改', 'updated_at', 'asc'),
  SortOption('updated_at-desc', '最新修改', 'updated_at', 'desc'),
  SortOption('created_at-asc', '最早上传', 'created_at', 'asc'),
  SortOption('created_at-desc', '最新上传', 'created_at', 'desc'),
];

/// 排序菜单（纯组件：把选中的排序 key 通过 [onSelected] 传出）。
class SortPopup extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const SortPopup(
      {super.key, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return AppPopup(
      child: SizedBox(
        // 屏幕高度不够时可滚动，避免菜单超出可视区域。
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final opt in sortOptions)
                InkWell(
                  onTap: () => onSelected(opt.key),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(opt.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 14,
                                  color: context.appColors.textPrimary)),
                        ),
                        if (selected == opt.key)
                          Icon(Icons.check,
                              size: 14, color: context.appColors.textPrimary),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 以 [anchorKey] 为锚点弹出排序菜单，选中后通过 [onSelected] 传出 key。
///
/// 主页与分享页共用；锚定按钮本身，避免各页再算固定坐标。
Future<void> showSortMenu(
  BuildContext context, {
  required GlobalKey anchorKey,
  required String selected,
  required ValueChanged<String> onSelected,
}) async {
  final key = await showAppPopup<String>(
    context: context,
    anchorKey: anchorKey,
    builder: (dialogContext) => SortPopup(
      selected: selected,
      onSelected: (value) => Navigator.of(dialogContext).pop(value),
    ),
  );
  if (key == null) return;
  onSelected(key);
}

/// 按排序 key 找到对应选项；未选择排序（空 key）或未知 key 返回 null。
SortOption? sortOptionFor(String key) {
  if (key.isEmpty) return null;
  for (final opt in sortOptions) {
    if (opt.key == key) return opt;
  }
  return null;
}
