import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/i18n/app_localizations.dart';
import '../core/theme/app_colors.dart';
import '../widgets/common/section_title.dart';
import '../widgets/common/settings_card.dart';

/// 关于页：版本信息、开源仓库、问题反馈、致谢与免责声明。
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  /// 开源仓库地址（页面里所有链接都从这里派生）。
  static const String repoUrl = 'https://github.com/TimeRunis/cloudreve_app';
  static const String repoLabel = 'github.com/TimeRunis/cloudreve_app';
  static const String issuesUrl = '$repoUrl/issues';

  PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _info = info);
    });
  }

  String _versionText(AppLocalizations l10n) {
    final info = _info;
    if (info == null) return l10n.t('读取中…');
    final build = info.buildNumber;
    return build.isEmpty ? info.version : '${info.version} ($build)';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: colors.contentBg,
      appBar: AppBar(
        backgroundColor: colors.headerBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: l10n.t('返回'),
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.t('关于'), style: TextStyle(color: colors.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(context, l10n),
          const SizedBox(height: 24),
          SectionTitle.settings(l10n.t('信息')),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.info_outline,
                title: l10n.t('版本'),
                subtitle: _versionText(l10n),
              ),
              SettingsTile(
                icon: Icons.code,
                title: l10n.t('开源仓库'),
                subtitle: repoLabel,
                trailing: IconButton(
                  tooltip: l10n.t('复制仓库地址'),
                  icon: Icon(Icons.copy_outlined,
                      size: 18, color: colors.textMuted),
                  onPressed: () => _copy(context, repoUrl, l10n.t('仓库地址已复制')),
                ),
                onTap: () => _openUrl(context, repoUrl),
              ),
              SettingsTile(
                icon: Icons.bug_report_outlined,
                title: l10n.t('问题反馈'),
                subtitle: l10n.t('在 GitHub Issues 提交问题或建议'),
                trailing: const SettingsChevron(),
                onTap: () => _openUrl(context, issuesUrl),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SectionTitle.settings(l10n.t('致谢')),
          SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.t(
                    '本项目基于 Flutter 构建，并使用了以下开源项目：\n'
                    'flutter_riverpod（状态管理）、dio（网络）、logger（日志）、'
                    'cached_network_image、video_player、video_thumbnail、'
                    'file_picker、gal、package_info_plus、url_launcher 等。\n'
                    '感谢 Cloudreve 及其社区提供的服务端与交互参考。',
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SectionTitle.settings(l10n.t('免责声明')),
          SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.t(
                    '本应用是 Cloudreve 的第三方客户端，非 Cloudreve 官方产品，'
                    '与 Cloudreve 官方团队无关。\n'
                    '账号、文件等数据均保存在你自行配置的 Cloudreve 站点上，'
                    '本应用不上传、不收集任何内容。',
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Made with Flutter · © 2026 TimeRunis',
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    final colors = context.appColors;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Image.asset(
            'assets/icon/cloudreve_1024.png',
            width: 96,
            height: 96,
            filterQuality: FilterQuality.medium,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Cloudreve',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.t('Cloudreve v4 的第三方 Flutter 客户端'),
          style: TextStyle(fontSize: 13, color: colors.textMuted),
        ),
      ],
    );
  }

  /// 用系统浏览器打开链接；失败时退回复制到剪贴板。
  Future<void> _openUrl(BuildContext context, String url) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      await _copy(context, url, AppLocalizations.of(context).t('链接已复制'));
    }
  }

  Future<void> _copy(BuildContext context, String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
