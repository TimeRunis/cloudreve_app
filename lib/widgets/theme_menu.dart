import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';

/// 主题切换菜单（跟随系统 / 亮色 / 暗色）。
class ThemeModeMenu extends ConsumerWidget {
  const ThemeModeMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(settingsProvider).themeMode;
    return PopupMenuButton<String>(
      icon: const Icon(Icons.brightness_6_outlined),
      tooltip: '主题',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) => ref.read(settingsProvider.notifier).setThemeMode(v),
      itemBuilder: (context) => [
        _item(context, '跟随系统', 'system', mode, Icons.brightness_auto),
        _item(context, '亮色', 'light', mode, Icons.light_mode_outlined),
        _item(context, '暗色', 'dark', mode, Icons.dark_mode_outlined),
      ],
    );
  }

  PopupMenuItem<String> _item(
    BuildContext context,
    String label,
    String value,
    String current,
    IconData icon,
  ) {
    final selected = current == value;
    final color =
        selected ? Theme.of(context).colorScheme.primary : null;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          if (selected) Icon(Icons.check, size: 18, color: color),
        ],
      ),
    );
  }
}
