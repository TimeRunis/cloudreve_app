import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../core/log/app_log.dart';
import '../core/theme/app_colors.dart';
import '../widgets/common/section_title.dart';
import '../widgets/common/settings_card.dart';
import '../widgets/settings/theme_setting_row.dart';
import 'settings_page.dart';

/// 统一设置入口（悬浮侧边栏 →「设置」）。
///
/// 只做聚合，不改变任何既有设置逻辑：
/// - 外观：整行点击弹出主题悬浮窗；
/// - 下载：跳转已有的「下载设置」页 [SettingsPage]；
/// - 日志：把 [AppLogger] 记录的日志导出成文件。
class SettingsHubPage extends ConsumerWidget {
  const SettingsHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.appColors.contentBg,
      appBar: AppBar(
        backgroundColor: context.appColors.headerBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: '返回',
          icon: Icon(Icons.arrow_back, color: context.appColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '设置',
          style: TextStyle(color: context.appColors.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionTitle.settings('外观'),
          const SettingsCard(children: [ThemeSettingRow()]),
          const SizedBox(height: 20),
          const SectionTitle.settings('下载'),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.download_outlined,
                title: '下载设置',
                subtitle: '多线程下载、下载线程数',
                trailing: const SettingsChevron(),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SectionTitle.settings('日志'),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.description_outlined,
                title: '导出日志',
                subtitle: '保存到本地文件，便于反馈问题',
                trailing: const SettingsChevron(),
                onTap: () => _exportLogs(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 导出日志并把文件路径回显给用户。
  Future<void> _exportLogs(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final String path;
    try {
      final file = await AppLogger.export();
      path = file.path;
    } catch (e, stackTrace) {
      AppLogger.log.e('[Settings] 导出日志失败', error: e, stackTrace: stackTrace);
      messenger.showSnackBar(SnackBar(content: Text('导出失败：$e')));
      return;
    }
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('日志已导出'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '可直接打开，或复制路径后自行处理',
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
            label: const Text('复制路径'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: path));
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              messenger.showSnackBar(
                const SnackBar(content: Text('日志路径已复制')),
              );
            },
          ),
          TextButton(
            onPressed: () => OpenFilex.open(path),
            child: const Text('打开文件'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
