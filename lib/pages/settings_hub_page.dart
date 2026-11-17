import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../core/log/app_log.dart';
import '../core/theme/app_colors.dart';
import '../providers/settings_provider.dart';
import '../widgets/popup/theme_popup.dart';
import 'settings_page.dart';

/// 统一设置入口（悬浮侧边栏 →「设置」）。
///
/// 这里只做聚合，不改变任何既有设置逻辑：
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
          const _SectionTitle('外观'),
          const _SettingsCard(
            children: [
              _ThemeSettingRow(),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionTitle('下载'),
          _SettingsCard(
            children: [
              ListTile(
                leading: Icon(
                  Icons.download_outlined,
                  color: context.appColors.textSecondary,
                ),
                title: Text('下载设置', style: _titleStyle(context)),
                subtitle: Text(
                  '多线程下载、下载线程数',
                  style: _subtitleStyle(context),
                ),
                trailing: _chevron(context),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionTitle('日志'),
          _SettingsCard(
            children: [
              ListTile(
                leading: Icon(
                  Icons.description_outlined,
                  color: context.appColors.textSecondary,
                ),
                title: Text('导出日志', style: _titleStyle(context)),
                subtitle: Text(
                  '保存到本地文件，便于反馈问题',
                  style: _subtitleStyle(context),
                ),
                trailing: _chevron(context),
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
            Text('可直接打开，或复制路径后自行处理', style: _subtitleStyle(dialogContext)),
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

/// 主题设置行：整行可点，点击后以该行为锚点弹出主题悬浮窗。
class _ThemeSettingRow extends ConsumerStatefulWidget {
  const _ThemeSettingRow();

  @override
  ConsumerState<_ThemeSettingRow> createState() => _ThemeSettingRowState();
}

class _ThemeSettingRowState extends ConsumerState<_ThemeSettingRow> {
  /// 锚点：悬浮窗按整行的位置对齐。
  final GlobalKey _anchorKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(settingsProvider).themeMode;
    return KeyedSubtree(
      key: _anchorKey,
      child: ListTile(
        leading: Icon(
          Icons.brightness_6_outlined,
          color: context.appColors.textSecondary,
        ),
        title: Text('主题', style: _titleStyle(context)),
        subtitle: Text(
          '当前：${_themeModeLabel(themeMode)}',
          style: _subtitleStyle(context),
        ),
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

String _themeModeLabel(String mode) {
  switch (mode) {
    case 'light':
      return '亮色';
    case 'dark':
      return '暗色';
    default:
      return '跟随系统';
  }
}

TextStyle _titleStyle(BuildContext context) => TextStyle(
      fontSize: 15,
      color: context.appColors.textPrimary,
    );

TextStyle _subtitleStyle(BuildContext context) => TextStyle(
      fontSize: 12,
      color: context.appColors.textMuted,
    );

Widget _chevron(BuildContext context) => Icon(
      Icons.chevron_right,
      color: context.appColors.textMuted,
    );

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: context.appColors.textSecondary,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}
