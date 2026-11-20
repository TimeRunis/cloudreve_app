import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/date_time.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/update/update_interval.dart';
import '../../providers/settings_provider.dart';
import '../../providers/update_provider.dart';
import '../common/settings_card.dart';
import '../popup/app_popup.dart';
import '../popup/popup_item.dart';
import '../update/update_flow.dart';

/// 设置页「检查更新」行：点按立即检查，副标题回显最近一次检查结果。
class UpdateCheckRow extends ConsumerStatefulWidget {
  /// 「立即更新」后跳到下载页的动作，由页面注入。
  final VoidCallback? onOpenDownloads;

  const UpdateCheckRow({super.key, this.onOpenDownloads});

  @override
  ConsumerState<UpdateCheckRow> createState() => _UpdateCheckRowState();
}

class _UpdateCheckRowState extends ConsumerState<UpdateCheckRow> {
  @override
  Widget build(BuildContext context) {
    final update = ref.watch(updateProvider);
    final l10n = AppLocalizations.of(context);
    final checking = update.status == UpdateCheckStatus.checking;
    return SettingsTile(
      icon: Icons.system_update_outlined,
      title: l10n.t('检查更新'),
      subtitle: _subtitle(update, l10n),
      trailing: checking
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.refresh, size: 18, color: context.appColors.textMuted),
      onTap: checking
          ? null
          : () => UpdateFlow.checkAndPrompt(
                context,
                ref,
                manual: true,
                onOpenDownloads: widget.onOpenDownloads,
              ),
    );
  }

  String _subtitle(UpdateState state, AppLocalizations l10n) {
    switch (state.status) {
      case UpdateCheckStatus.idle:
        final last = state.lastCheckAt;
        return last == null
            ? l10n.t('检查 GitHub 上是否有新版本')
            : l10n.t('上次检查：{time}', args: {'time': formatDateTime(last)});
      case UpdateCheckStatus.checking:
        return l10n.t('正在检查新版本…');
      case UpdateCheckStatus.upToDate:
        return l10n.t('已是最新版本');
      case UpdateCheckStatus.available:
        return l10n.t(
          '发现新版本 {version}',
          args: {'version': state.release?.versionLabel ?? ''},
        );
      case UpdateCheckStatus.failed:
        return l10n.t('检查失败，点击重试');
    }
  }
}

/// 设置页「自动检查更新」行：点按弹出频率悬浮窗（启动 / 1 / 7 / 30 天）。
class UpdateIntervalRow extends ConsumerStatefulWidget {
  const UpdateIntervalRow({super.key});

  @override
  ConsumerState<UpdateIntervalRow> createState() => _UpdateIntervalRowState();
}

class _UpdateIntervalRowState extends ConsumerState<UpdateIntervalRow> {
  final GlobalKey _anchorKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final interval = ref.watch(settingsProvider).updateCheckInterval;
    final l10n = AppLocalizations.of(context);
    return KeyedSubtree(
      key: _anchorKey,
      child: SettingsTile(
        icon: Icons.schedule,
        title: l10n.t('自动检查更新'),
        subtitle: l10n.t(
          '当前：{label}',
          args: {'label': _intervalLabel(l10n, interval)},
        ),
        trailing: Icon(Icons.expand_more, color: context.appColors.textMuted),
        onTap: _openPicker,
      ),
    );
  }

  Future<void> _openPicker() async {
    final current = ref.read(settingsProvider).updateCheckInterval;
    final l10n = AppLocalizations.of(context);
    final selected = await showAppPopup<UpdateCheckInterval>(
      context: context,
      anchorKey: _anchorKey,
      builder: (popupContext) => AppPopup(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in UpdateCheckInterval.values)
              PopupItem(
                icon: _iconFor(option),
                label: _intervalLabel(l10n, option),
                selected: option == current,
                onTap: () => Navigator.of(popupContext).pop(option),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    await ref.read(settingsProvider.notifier).setUpdateCheckInterval(selected);
  }

  String _intervalLabel(
    AppLocalizations l10n,
    UpdateCheckInterval interval,
  ) =>
      switch (interval) {
        UpdateCheckInterval.launch => l10n.t('每次启动'),
        UpdateCheckInterval.daily => l10n.t('每天'),
        UpdateCheckInterval.weekly => l10n.t('每 7 天'),
        UpdateCheckInterval.monthly => l10n.t('每 30 天'),
      };

  IconData _iconFor(UpdateCheckInterval interval) => switch (interval) {
        UpdateCheckInterval.launch => Icons.rocket_launch_outlined,
        UpdateCheckInterval.daily => Icons.today_outlined,
        UpdateCheckInterval.weekly => Icons.date_range_outlined,
        UpdateCheckInterval.monthly => Icons.calendar_month_outlined,
      };
}
