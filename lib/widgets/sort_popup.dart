import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

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

  const SortPopup({super.key, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 8,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final opt in sortOptions)
              InkWell(
                onTap: () => onSelected(opt.key),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
    );
  }
}
