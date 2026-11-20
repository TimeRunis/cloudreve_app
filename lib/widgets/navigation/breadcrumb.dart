import 'package:flutter/material.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/directory_provider.dart';

/// 面包屑：可左右滑动的路径层级，末尾目录带朝下箭头；路径变化后自动滚到最右。
///
/// 纯展示组件：路径以「层级列表」传入，点击通过 [onNavigate] 传出目标深度
/// （0 = 根，i = 保留前 i 段），不直接依赖任何 provider。
class Breadcrumb extends StatefulWidget {
  /// 当前路径层级（原始段，渲染时解码）。
  final List<String> segments;

  /// 分类视图（图片/视频/音乐/文档）；非空时替代普通层级显示。
  final FileCategory? category;

  /// 根节点文案与图标，分享页可换成分享名；为空时用「我的文件」。
  final String? rootLabel;
  final IconData rootIcon;

  /// 点击某一层：0 = 根，i = 保留前 i 段。
  final ValueChanged<int> onNavigate;

  /// 点击末尾目录（打开其操作菜单）；为空时末尾目录不可点、也不显示下拉箭头。
  final VoidCallback? onOpenCurrentMenu;

  const Breadcrumb({
    super.key,
    required this.segments,
    this.category,
    this.rootLabel,
    this.rootIcon = Icons.home_outlined,
    required this.onNavigate,
    this.onOpenCurrentMenu,
  });

  @override
  State<Breadcrumb> createState() => _BreadcrumbState();
}

class _BreadcrumbState extends State<Breadcrumb> {
  final ScrollController _controller = ScrollController();

  @override
  void didUpdateWidget(covariant Breadcrumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segments.join('/') != widget.segments.join('/')) {
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
    final segments = widget.segments;
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
                    Icon(widget.rootIcon,
                        size: 18, color: context.appColors.textPrimary),
                    const SizedBox(width: 6),
                    Text(widget.rootLabel ?? tr('我的文件'),
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: context.appColors.textPrimary)),
                  ],
                ),
                onTap: () => widget.onNavigate(0),
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
                      Text(
                          AppLocalizations.of(context)
                              .t(widget.category!.label),
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
                        ? widget.onOpenCurrentMenu
                        : () => widget.onNavigate(i + 1),
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
        if (isLast && widget.onOpenCurrentMenu != null)
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
