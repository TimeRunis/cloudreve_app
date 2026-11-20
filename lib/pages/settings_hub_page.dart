import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../core/i18n/app_localizations.dart';
import '../core/log/app_log.dart';
import '../core/theme/app_colors.dart';
import '../widgets/common/section_title.dart';
import '../widgets/common/settings_card.dart';
import '../widgets/settings/language_setting_row.dart';
import '../widgets/settings/theme_setting_row.dart';
import '../widgets/settings/update_settings_row.dart';
import 'about_page.dart';
import 'downloads_page.dart';
import 'settings_page.dart';
import 'site_list_page.dart';

/// 统一设置入口（悬浮侧边栏 →「设置」）。
///
/// 只做聚合，不改变任何既有设置逻辑：
/// - 外观：整行点击弹出主题 / 语言悬浮窗；
/// - 下载：跳转已有的「下载设置」页 [SettingsPage]；
/// - 日志：把 [AppLogger] 记录的日志导出成文件。
class SettingsHubPage extends ConsumerWidget {
  const SettingsHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: context.appColors.contentBg,
      appBar: AppBar(
        backgroundColor: context.appColors.headerBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: l10n.t('返回'),
          icon: Icon(Icons.arrow_back, color: context.appColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.t('设置'),
          style: TextStyle(color: context.appColors.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionTitle.settings(l10n.t('外观')),
          const SettingsCard(
            children: [ThemeSettingRow(), LanguageSettingRow()],
          ),
          const SizedBox(height: 20),
          SectionTitle.settings(l10n.t('站点')),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.dns_outlined,
                title: l10n.t('管理站点'),
                subtitle: l10n.t('添加、切换、编辑或删除站点'),
                trailing: const SettingsChevron(),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SiteListPage()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SectionTitle.settings(l10n.t('下载')),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.download_outlined,
                title: l10n.t('下载设置'),
                subtitle: l10n.t('多线程下载、下载线程数'),
                trailing: const SettingsChevron(),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SectionTitle.settings(l10n.t('日志')),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.description_outlined,
                title: l10n.t('导出日志'),
                subtitle: l10n.t('保存到本地文件，便于反馈问题'),
                trailing: const SettingsChevron(),
                onTap: () => _exportLogs(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SectionTitle.settings(l10n.t('更新')),
          SettingsCard(
            children: [
              UpdateCheckRow(onOpenDownloads: () => _openDownloads(context)),
              const UpdateIntervalRow(),
            ],
          ),
          const SizedBox(height: 20),
          SectionTitle.settings(l10n.t('关于')),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.info_outline,
                title: l10n.t('关于 Cloudreve'),
                subtitle: l10n.t('版本、开源仓库与致谢'),
                trailing: const SettingsChevron(),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AboutPage()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 跳转下载页（「立即更新」把安装包加入队列后直达进度）。
  void _openDownloads(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DownloadsPage()),
    );
  }

  /// 导出日志并把文件路径回显给用户。
  Future<void> _exportLogs(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final String path;
    try {
      final file = await AppLogger.export();
      path = file.path;
    } catch (e, stackTrace) {
      AppLogger.log
          .e(tr('[Settings] 导出日志失败'), error: e, stackTrace: stackTrace);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.t('导出失败：{error}', args: {'error': '$e'})),
        ),
      );
      return;
    }
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final dialogL10n = AppLocalizations.of(dialogContext);
        return AlertDialog(
          title: Text(dialogL10n.t('日志已导出')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dialogL10n.t('可直接打开，或复制路径后自行处理'),
                style: TextStyle(
                  fontSize: 12,
                  color: dialogContext.appColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                path,
                style: TextStyle(
                  fontSize: 12,
                  color: dialogContext.appColors.textMuted,
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.copy_outlined, size: 18),
              label: Text(dialogL10n.t('复制路径')),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: path));
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                messenger.showSnackBar(
                  SnackBar(content: Text(dialogL10n.t('日志路径已复制'))),
                );
              },
            ),
            TextButton(
              onPressed: () => OpenFilex.open(path),
              child: Text(dialogL10n.t('打开文件')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(dialogL10n.t('关闭')),
            ),
          ],
        );
      },
    );
  }
}
