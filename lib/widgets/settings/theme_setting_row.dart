import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_mode_label.dart';
import '../../providers/settings_provider.dart';
import '../common/settings_card.dart';
import '../popup/theme_popup.dart';

/// 设置页「主题」行：整行可点，点击后以该行为锚点弹出主题悬浮窗。
class ThemeSettingRow extends ConsumerStatefulWidget {
  const ThemeSettingRow({super.key});

  @override
  ConsumerState<ThemeSettingRow> createState() => _ThemeSettingRowState();
}

class _ThemeSettingRowState extends ConsumerState<ThemeSettingRow> {
  /// 锚点：悬浮窗按整行的位置对齐。
  final GlobalKey _anchorKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(settingsProvider).themeMode;
    return KeyedSubtree(
      key: _anchorKey,
      child: SettingsTile(
        icon: Icons.brightness_6_outlined,
        title: '主题',
        subtitle: '当前：${themeModeLabel(themeMode)}',
        trailing: Icon(Icons.expand_more, color: context.appColors.textMuted),
        onTap: () => showThemePicker(
          context: context,
          ref: ref,
          anchorKey: _anchorKey,
        ),
      ),
    );
  }
}
