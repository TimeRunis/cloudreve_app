import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/directory_provider.dart';

/// 面包屑：可左右滑动的路径层级，末尾目录带朝下箭头；路径变化后自动滚到最右。
class Breadcrumb extends StatefulWidget {
  final String path;
  final FileCategory? category;
  final ValueChanged<String> onNavigate;
  final VoidCallback onOpenCurrentPopup;

  const Breadcrumb({
    super.key,
    required this.path,
    this.category,
    required this.onNavigate,
    required this.onOpenCurrentPopup,
  });

  @override
  State<Breadcrumb> createState() => _BreadcrumbState();
}

class _BreadcrumbState extends State<Breadcrumb> {
  final ScrollController _controller = ScrollController();

  @override
  void didUpdateWidget(covariant Breadcrumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _scrollToEnd();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) return;
      _controller.jumpTo(_controller.position.maxScrollExtent);
    });
  }

  List<String> get _segments =>
      widget.path.split('/').where((s) => s.isNotEmpty).toList();

  String _pathFor(int index) => '/${_segments.sublist(0, index + 1).join('/')}';

  /// 面包屑显示用：URL 解码目录名（不改动内部路径）。
  String _decodeSegment(String s) {
    try {
      return Uri.decodeComponent(s);
    } catch (_) {
      return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final segments = _segments;
    return Material(
      color: context.appColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: context.appColors.toolbarBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: SizedBox(
          height: 40,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _crumb(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.home_outlined,
                        size: 18, color: context.appColors.textPrimary),
                    const SizedBox(width: 6),
                    Text('我的文件',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: context.appColors.textPrimary)),
                  ],
                ),
                onTap: () => widget.onNavigate('/'),
              ),
              if (widget.category != null) ...[
                Icon(Icons.chevron_right,
                    size: 16, color: context.appColors.textFaint),
                _crumb(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_categoryIcon(widget.category!),
                          size: 18, color: context.appColors.textPrimary),
                      const SizedBox(width: 6),
                      Text(widget.category!.label,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: context.appColors.textPrimary)),
                    ],
                  ),
                  onTap: null,
                ),
              ] else
                for (int i = 0; i < segments.length; i++) ...[
                  Icon(Icons.chevron_right,
                      size: 16, color: context.appColors.textFaint),
                  _crumb(
                    _segmentLabel(
                        _decodeSegment(segments[i]), i == segments.length - 1),
                    onTap: i == segments.length - 1
                        ? widget.onOpenCurrentPopup
                        : () => widget.onNavigate(_pathFor(i)),
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }

  /// 面包屑单元：包裹点击，墨水展开区域与面包屑上下边缘留出间距。
  Widget _crumb(Widget child, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: child,
      ),
    );
  }

  /// 目录段标签：末尾段加粗并紧贴一个朝下箭头。
  Widget _segmentLabel(String name, bool isLast) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isLast ? FontWeight.w600 : FontWeight.w500,
            color: context.appColors.textPrimary,
          ),
        ),
        if (isLast)
          Icon(Icons.arrow_drop_down,
              size: 20, color: context.appColors.textSecondary),
      ],
    );
  }
}

/// 分类对应的图标。
IconData _categoryIcon(FileCategory category) {
  switch (category) {
    case FileCategory.image:
      return Icons.image_outlined;
    case FileCategory.video:
      return Icons.videocam_outlined;
    case FileCategory.music:
      return Icons.music_note_outlined;
    case FileCategory.doc:
      return Icons.description_outlined;
  }
}
