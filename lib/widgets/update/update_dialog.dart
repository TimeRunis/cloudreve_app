import 'package:flutter/material.dart';

import '../../core/format/date_time.dart';
import '../../core/theme/app_colors.dart';
import '../../models/app_release.dart';
import '../file/file_icon.dart';
import 'update_notes.dart';
import '../../core/i18n/app_localizations.dart';

/// 更新弹窗里用户选择的动作。
enum UpdateDialogAction {
  /// 以后再说。
  later,

  /// 立即更新：把安装包加入下载队列。
  download,

  /// 打开发布页（没有可直接下载的安装包时）。
  openPage,
}

/// 「发现新版本」弹窗：展示版本变化、更新说明与体积，并让用户决定是否更新。
Future<UpdateDialogAction> showUpdateDialog(
  BuildContext context, {
  required AppRelease release,
  required String currentVersion,
}) async {
  final action = await showDialog<UpdateDialogAction>(
    context: context,
    builder: (_) => _UpdateDialog(
      release: release,
      currentVersion: currentVersion,
    ),
  );
  return action ?? UpdateDialogAction.later;
}

/// 「安装包已下载」弹窗：返回 true 表示立即安装。
Future<bool> showUpdateReadyDialog(
  BuildContext context, {
  required String fileName,
  String? version,
}) async {
  final install = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final colors = dialogContext.appColors;
      final primary = Theme.of(dialogContext).colorScheme.primary;
      final isIpa = fileName.toLowerCase().endsWith('.ipa');
      return _DialogShell(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _IconBadge(
                  icon: Icons.download_done,
                  color: Colors.green,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isIpa ? tr('iOS 安装包已下载') : tr('新版本已下载'),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              version == null
                  ? (isIpa ? tr('iOS 安装包下载完成，是否打开？') : tr('安装包下载完成，是否立即安装？'))
                  : (isIpa
                      ? tr('Cloudreve {version} iOS 安装包下载完成，是否打开？',
                          args: {'version': version})
                      : tr('Cloudreve {version} 安装包下载完成，是否立即安装？',
                          args: {'version': version})),
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    isIpa ? Icons.phone_iphone : Icons.android,
                    size: 16,
                    color: colors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: colors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(tr('稍后')),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: primary),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(isIpa ? tr('打开文件') : tr('立即安装')),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
  return install ?? false;
}

/// 发现新版本弹窗本体。
class _UpdateDialog extends StatelessWidget {
  final AppRelease release;
  final String currentVersion;

  const _UpdateDialog({required this.release, required this.currentVersion});

  bool get _canDownload => release.hasPlatformPackage;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final primary = Theme.of(context).colorScheme.primary;
    final published = release.publishedAt == null
        ? ''
        : formatDateTime(release.publishedAt).split(' ').first;
    final size =
        release.platformSize == null ? '' : formatSize(release.platformSize!);
    final meta = [published, size].where((e) => e.isNotEmpty).join(' · ');

    return _DialogShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(icon: Icons.system_update_alt, color: primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('发现新版本'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      release.isPrerelease ? tr('预发布版本') : tr('正式版本'),
                      style: TextStyle(fontSize: 12, color: colors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _VersionTag(label: tr('当前'), value: currentVersion),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 14,
                    color: colors.textMuted,
                  ),
                ),
                _VersionTag(
                  label: tr('最新'),
                  value: release.versionLabel,
                  highlighted: true,
                ),
              ],
            ),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              meta,
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            tr('更新内容'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 220),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child: release.notes.isEmpty
                  ? Text(
                      tr('该版本没有提供更新说明。'),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: colors.textSecondary,
                      ),
                    )
                  : UpdateNotesView(markdown: release.notes),
            ),
          ),
          if (!_canDownload) ...[
            const SizedBox(height: 8),
            Text(
              tr('没有找到可直接下载的安装包，请在发布页手动下载。'),
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              if (_canDownload)
                TextButton(
                  onPressed: () => Navigator.of(context).pop(
                    UpdateDialogAction.openPage,
                  ),
                  child: Text(tr('打开发布页')),
                ),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(UpdateDialogAction.later),
                child: Text(tr('以后再说')),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: primary),
                icon: Icon(
                  _canDownload ? Icons.download_outlined : Icons.open_in_new,
                  size: 18,
                ),
                label: Text(_canDownload ? tr('立即更新') : tr('打开发布页')),
                onPressed: () => Navigator.of(context).pop(
                  _canDownload
                      ? UpdateDialogAction.download
                      : UpdateDialogAction.openPage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 弹窗统一外壳：固定外观，内容只关心纵向排列。
class _DialogShell extends StatelessWidget {
  final Widget child;

  const _DialogShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.appColors.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: child,
        ),
      ),
    );
  }
}

/// 圆角图标底衬。
class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconBadge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 22, color: color),
    );
  }
}

/// 「当前 / 最新」版本小标签。
class _VersionTag extends StatelessWidget {
  final String label;
  final String value;
  final bool highlighted;

  const _VersionTag({
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: colors.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: highlighted ? FontWeight.w600 : FontWeight.w400,
              color: highlighted
                  ? Theme.of(context).colorScheme.primary
                  : colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
