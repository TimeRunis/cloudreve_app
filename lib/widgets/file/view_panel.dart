import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../popup/app_popup.dart';
import '../../core/i18n/app_localizations.dart';

/// 视图设置面板（受控组件：持有本地选中态，把变化通过回调传出）。
class ViewPanel extends StatefulWidget {
  final String initialViewMode;
  final bool initialThumbnails;
  final int initialPageSize;
  final ValueChanged<String> onViewModeChanged;
  final ValueChanged<bool> onThumbnailsChanged;
  final ValueChanged<int> onPageSizeChanged;

  const ViewPanel({
    super.key,
    required this.initialViewMode,
    required this.initialThumbnails,
    required this.initialPageSize,
    required this.onViewModeChanged,
    required this.onThumbnailsChanged,
    required this.onPageSizeChanged,
  });

  @override
  State<ViewPanel> createState() => _ViewPanelState();
}

class _ViewPanelState extends State<ViewPanel> {
  late String _viewMode = widget.initialViewMode;
  late bool _thumbnails = widget.initialThumbnails;
  late int _pageSize = widget.initialPageSize;

  @override
  Widget build(BuildContext context) {
    final titleStyle =
        TextStyle(fontSize: 14, color: context.appColors.textSecondary);
    return AppPopup(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('布局'), style: titleStyle),
              const SizedBox(height: 8),
              SegmentedGroup<String>(
                options: [
                  (Icons.grid_view, tr('网格'), 'grid'),
                  (Icons.view_list, tr('列表'), 'list'),
                ],
                value: _viewMode,
                onChanged: (v) {
                  setState(() => _viewMode = v);
                  widget.onViewModeChanged(v);
                },
              ),
              const SizedBox(height: 16),
              Text(tr('缩略图'), style: titleStyle),
              const SizedBox(height: 8),
              SegmentedGroup<bool>(
                options: [
                  (Icons.image_outlined, tr('开启'), true),
                  (Icons.hide_image_outlined, tr('关闭'), false),
                ],
                value: _thumbnails,
                onChanged: (v) {
                  setState(() => _thumbnails = v);
                  widget.onThumbnailsChanged(v);
                },
              ),
              const SizedBox(height: 16),
              Text(tr('分页大小'), style: titleStyle),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      min: 50,
                      max: 2000,
                      value: _pageSize.toDouble().clamp(50, 2000),
                      onChanged: (v) {
                        setState(() => _pageSize = v.round());
                        widget.onPageSizeChanged(v.round());
                      },
                    ),
                  ),
                  Text('$_pageSize',
                      style: TextStyle(
                          fontSize: 13,
                          color: context.appColors.textSecondary)),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('50',
                        style: TextStyle(
                            fontSize: 12,
                            color: context.appColors.textSecondary)),
                    Text('2000',
                        style: TextStyle(
                            fontSize: 12,
                            color: context.appColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 分段选择组（布局 / 缩略图）。
class SegmentedGroup<T> extends StatelessWidget {
  final List<(IconData, String, T)> options;
  final T value;
  final ValueChanged<T> onChanged;

  const SegmentedGroup({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.appColors.toolbarBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          for (int i = 0; i < options.length; i++) ...[
            if (i > 0)
              Container(
                  width: 1, height: 28, color: context.appColors.toolbarBorder),
            Expanded(
              child: InkWell(
                onTap: () => onChanged(options[i].$3),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: options[i].$3 == value
                        ? scheme.primaryContainer
                        : context.appColors.surface,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(options[i].$1,
                          size: 14,
                          color: options[i].$3 == value
                              ? scheme.primary
                              : context.appColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(options[i].$2,
                          style: TextStyle(
                              fontSize: 13,
                              color: options[i].$3 == value
                                  ? scheme.primary
                                  : context.appColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
