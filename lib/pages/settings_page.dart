import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../providers/settings_provider.dart';

/// 下载设置页面（从下载页右上角「更多 → 下载设置」进入）。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
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
        title: Text('下载设置',
            style: TextStyle(color: context.appColors.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle('多线程下载'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: context.appColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.appColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                SwitchListTile(
                  value: settings.multiThreadDownload,
                  activeColor: Theme.of(context).colorScheme.primary,
                  title: Text(
                    '多线程下载',
                    style: TextStyle(
                      fontSize: 15,
                      color: context.appColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    '使用 HTTP Range 分片并行下载，适合大文件',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appColors.textMuted,
                    ),
                  ),
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .setMultiThreadDownload(v),
                ),
                Divider(height: 1, color: context.appColors.border),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '下载线程数',
                            style: TextStyle(
                              fontSize: 15,
                              color: settings.multiThreadDownload
                                  ? context.appColors.textPrimary
                                  : context.appColors.textMuted,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${settings.downloadThreadCount}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: settings.multiThreadDownload
                                  ? Theme.of(context).colorScheme.primary
                                  : context.appColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: settings.downloadThreadCount
                            .toDouble()
                            .clamp(2, 16)
                            .toDouble(),
                        min: 2,
                        max: 16,
                        divisions: 14,
                        activeColor: Theme.of(context).colorScheme.primary,
                        inactiveColor: context.appColors.surfaceMuted,
                        onChanged: settings.multiThreadDownload
                            ? (v) => ref
                                .read(settingsProvider.notifier)
                                .setDownloadThreadCount(v.round())
                            : null,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('2',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: context.appColors.textMuted)),
                          Text('16',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: context.appColors.textMuted)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        settings.multiThreadDownload
                            ? '仅对大于 1MB 的文件生效；服务器不支持时自动降级单线程'
                            : '开启后可为每个文件分配多个线程并行下载',
                        style: TextStyle(
                            fontSize: 12,
                            color: context.appColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
