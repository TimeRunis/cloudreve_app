import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/settings_provider.dart';
import 'app_popup.dart';
import 'popup_item.dart';

/// 主题选择悬浮窗（跟随系统 / 亮色 / 暗色）。
///
/// 只负责展示，选中值通过 `Navigator.pop(mode)` 交回给 [ThemeModeMenu]，
/// 与其余菜单共用 [AppPopup] 的外观。
class ThemeModePopup extends StatelessWidget {
  final String selected;

  const ThemeModePopup({super.key, required this.selected});

  static const List<(String, String, IconData)> options = [
    ('system', '跟随系统', Icons.brightness_auto),
    ('light', '亮色', Icons.light_mode_outlined),
    ('dark', '暗色', Icons.dark_mode_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return AppPopup(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            PopupItem(
              icon: option.$3,
              label: option.$2,
              selected: selected == option.$1,
              onTap: () => Navigator.of(context).pop(option.$1),
            ),
        ],
      ),
    );
  }
}

/// 以 [anchorKey] 对应的控件为锚点弹出主题选择，并把结果写回设置。
///
/// 悬浮触发器（图标按钮、整行 ListTile 等）都可以直接复用。
Future<void> showThemePicker({
  required BuildContext context,
  required WidgetRef ref,
  required GlobalKey anchorKey,
}) async {
  final selected = await showAppPopup<String>(
    context: context,
    anchorKey: anchorKey,
    builder: (_) => ThemeModePopup(
      selected: ref.read(settingsProvider).themeMode,
    ),
  );
  if (selected == null || !context.mounted) return;
  await ref.read(settingsProvider.notifier).setThemeMode(selected);
}

/// 主题切换按钮：点按后以自身为锚点弹出 [ThemeModePopup]。
class ThemeModeMenu extends ConsumerStatefulWidget {
  const ThemeModeMenu({super.key});

  @override
  ConsumerState<ThemeModeMenu> createState() => _ThemeModeMenuState();
}

class _ThemeModeMenuState extends ConsumerState<ThemeModeMenu> {
  /// 锚点：悬浮窗根据它的位置对齐到按钮下方。
  final GlobalKey _anchorKey = GlobalKey();

  Future<void> _open() => showThemePicker(
        context: context,
        ref: ref,
        anchorKey: _anchorKey,
      );

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _anchorKey,
      child: IconButton(
        tooltip: '主题',
        icon: Icon(
          Icons.brightness_6_outlined,
          color: context.appColors.textSecondary,
        ),
        onPressed: _open,
      ),
    );
  }
}
