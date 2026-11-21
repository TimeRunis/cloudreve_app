import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/log/app_log.dart';
import '../../models/app_release.dart';
import '../../models/download_task.dart';
import '../../providers/update_provider.dart';
import 'update_dialog.dart';
import '../../core/i18n/app_localizations.dart';

/// 「检查更新 → 弹窗 → 加入下载队列 → 提示安装」的完整交互流程。
///
/// 启动检查（设置里的自动检查频率）和设置页的手动检查共用这一套逻辑，
/// 下载本身复用全局下载队列与下载页，不额外实现一套进度界面。
class UpdateFlow {
  UpdateFlow._();

  /// 弹窗互斥：启动检查与手动检查同时命中新版本时只弹一次。
  static bool _prompting = false;

  /// 检查更新；[manual] 为 true 时无论结果如何都会给出提示。
  ///
  /// [onOpenDownloads] 用于「立即更新」后跳到下载页，由调用方决定跳转方式，
  /// 避免这里反向依赖页面。
  static Future<void> checkAndPrompt(
    BuildContext context,
    WidgetRef ref, {
    required bool manual,
    VoidCallback? onOpenDownloads,
  }) async {
    if (_prompting) return;
    final notifier = ref.read(updateProvider.notifier);
    final release = await notifier.check();
    if (!context.mounted) return;

    final state = ref.read(updateProvider);
    if (release == null) {
      if (manual) {
        final message = state.status == UpdateCheckStatus.failed
            ? tr('检查更新失败：{error}', args: {'error': state.error ?? tr('网络异常')})
            : tr('当前已是最新版本');
        _toast(context, message);
      }
      return;
    }

    if (!manual && notifier.wasPrompted(release)) return;
    if (_prompting) return;
    _prompting = true;
    notifier.markPrompted(release);
    try {
      // 自动检查发生在启动阶段：等启动时的其它弹窗（如分享链接确认）结束。
      if (!manual && !await _waitUntilVisible(context)) return;
      if (!context.mounted) return;

      final action = await showUpdateDialog(
        context,
        release: release,
        currentVersion: state.installedVersion ?? '',
      );
      if (!context.mounted) return;
      switch (action) {
        case UpdateDialogAction.later:
          break;
        case UpdateDialogAction.openPage:
          await _openReleasePage(context, release);
          break;
        case UpdateDialogAction.download:
          await _startDownload(context, ref, release, onOpenDownloads);
          break;
      }
    } finally {
      _prompting = false;
    }
  }

  /// 下载完成后提示安装（由下载队列完成事件触发）。
  static Future<void> promptInstall(
    BuildContext context,
    DownloadTask task, {
    String? version,
  }) async {
    final install = await showUpdateReadyDialog(
      context,
      fileName: task.name,
      version: version,
    );
    if (!install || !context.mounted) return;
    final opened = await _openInstaller(task.savePath);
    if (!opened && context.mounted) {
      _toast(context, tr('无法启动安装器，请在下载页打开安装包'));
    }
  }

  // ---------- 内部步骤 ----------

  static Future<void> _startDownload(
    BuildContext context,
    WidgetRef ref,
    AppRelease release,
    VoidCallback? onOpenDownloads,
  ) async {
    final task = await ref.read(updateProvider.notifier).download(release);
    if (!context.mounted) return;
    if (task == null) {
      // 不自动跳发布页：这里只提示，用户点「打开发布页」再跳转。
      _toastWithAction(
        context,
        tr('无法开始下载，请在发布页手动下载'),
        tr('打开发布页'),
        () => _openReleasePage(context, release),
      );
      return;
    }
    if (task.status == DownloadStatus.completed) {
      await promptInstall(context, task, version: release.versionLabel);
      return;
    }
    _toast(context, tr('已加入下载队列，可在下载页查看进度'));
    onOpenDownloads?.call();
  }

  static Future<bool> _openInstaller(String path) async {
    try {
      final result = await OpenFilex.open(path);
      return result.type == ResultType.done;
    } catch (e) {
      AppLogger.log.w('[Update] 启动安装器失败：$e');
      return false;
    }
  }

  static Future<void> _openReleasePage(
    BuildContext context,
    AppRelease release,
  ) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(release.pageUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      AppLogger.log.w('[Update] 打开发布页失败：$e');
    }
    if (opened || !context.mounted) return;
    await Clipboard.setData(ClipboardData(text: release.pageUrl));
    if (!context.mounted) return;
    _toast(context, tr('发布页地址已复制到剪贴板'));
  }

  /// 等当前页面重新回到栈顶（最多约 8 秒），避免和其它弹窗叠在一起。
  static Future<bool> _waitUntilVisible(BuildContext context) async {
    for (var i = 0; i < 12; i++) {
      if (!context.mounted) return false;
      final route = ModalRoute.of(context);
      if (route == null || route.isCurrent) return true;
      await Future.delayed(const Duration(milliseconds: 700));
    }
    return false;
  }

  static void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  static void _toastWithAction(
    BuildContext context,
    String message,
    String actionLabel,
    VoidCallback onAction,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(label: actionLabel, onPressed: onAction),
      ),
    );
  }
}
