import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_language.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/settings_provider.dart';
import '../common/settings_card.dart';
import '../popup/app_popup.dart';
import '../popup/popup_item.dart';

/// 设置页「语言」行：点按弹出语言悬浮窗（跟随系统 / 简体中文 / English）。
class LanguageSettingRow extends ConsumerStatefulWidget {
  const LanguageSettingRow({super.key});

  @override
  ConsumerState<LanguageSettingRow> createState() => _LanguageSettingRowState();
}

class _LanguageSettingRowState extends ConsumerState<LanguageSettingRow> {
  /// 锚点：悬浮窗按整行位置对齐。
  final GlobalKey _anchorKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(settingsProvider).language;
    final l10n = AppLocalizations.of(context);
    return KeyedSubtree(
      key: _anchorKey,
      child: SettingsTile(
        icon: Icons.translate,
        title: l10n.t('语言'),
        subtitle: l10n.t(
          '当前：{label}',
          args: {'label': _languageLabel(l10n, language)},
        ),
        trailing: Icon(Icons.expand_more, color: context.appColors.textMuted),
        onTap: _openPicker,
      ),
    );
  }

  Future<void> _openPicker() async {
    final current = ref.read(settingsProvider).language;
    final l10n = AppLocalizations.of(context);
    final selected = await showAppPopup<AppLanguage>(
      context: context,
      anchorKey: _anchorKey,
      builder: (popupContext) => AppPopup(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final language in AppLanguage.values)
              PopupItem(
                icon: _iconFor(language),
                label: _languageLabel(l10n, language),
                selected: language == current,
                onTap: () => Navigator.of(popupContext).pop(language),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    await ref.read(settingsProvider.notifier).setLanguage(selected);
  }

  /// 语言名称用该语言自身书写，避免切到英文后看不懂。
  String _languageLabel(AppLocalizations l10n, AppLanguage language) {
    if (language == AppLanguage.system) return l10n.t('跟随系统');
    return language.label;
  }

  IconData _iconFor(AppLanguage language) => switch (language) {
        AppLanguage.system => Icons.brightness_auto,
        AppLanguage.zh => Icons.translate,
        AppLanguage.en => Icons.translate,
      };
}
