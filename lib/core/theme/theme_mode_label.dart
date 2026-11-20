import '../i18n/app_localizations.dart';

/// 主题模式（system / light / dark）对应的当前语言名称。
///
/// 侧边栏、设置页、主题悬浮窗共用，避免各处再写一份 switch。
String themeModeLabel(String mode, AppLocalizations l10n) {
  switch (mode) {
    case 'light':
      return l10n.t('亮色');
    case 'dark':
      return l10n.t('暗色');
    default:
      return l10n.t('跟随系统');
  }
}
