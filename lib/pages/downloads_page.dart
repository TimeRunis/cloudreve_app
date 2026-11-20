import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../models/download_task.dart';
import '../providers/download_provider.dart';
import '../widgets/common/empty_view.dart';
import '../widgets/download/download_summary_card.dart';
import '../widgets/download/download_task_card.dart';
import '../widgets/download/downloads_menu_popup.dart';
import '../widgets/popup/app_popup.dart';
import 'settings_page.dart';
import '../core/i18n/app_localizations.dart';

/// 下载页面：下载中 / 已完成 / 下载失败三个分类。
class DownloadsPage extends ConsumerStatefulWidget {
  const DownloadsPage({super.key});

  @override
  ConsumerState<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends ConsumerState<DownloadsPage> {
  final GlobalKey _moreKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(downloadManagerProvider).manager;
    final tabs = [tr('下载中'), tr('已完成'), tr('下载失败')];
    // 直接监听 ChangeNotifier，保证进度 / 状态每次都实时刷新。
    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        final tasks = manager.tasks;
        final downloading = _inProgressTasks(tasks);
        final completed =
            tasks.where((t) => t.status == DownloadStatus.completed).toList();
        final failed =
            tasks.where((t) => t.status == DownloadStatus.failed).toList();
        final active =
            tasks.where((t) => t.status != DownloadStatus.completed).toList();

        return DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            backgroundColor: context.appColors.contentBg,
            appBar: AppBar(
              backgroundColor: context.appColors.headerBg,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                tooltip: tr('返回'),
                icon: Icon(Icons.arrow_back,
                    color: context.appColors.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(tr('下载'),
                  style: TextStyle(color: context.appColors.textPrimary)),
              actions: [
                IconButton(
                  key: _moreKey,
                  tooltip: tr('更多操作'),
                  icon: Icon(Icons.more_horiz,
                      color: context.appColors.textPrimary),
                  onPressed: _openMoreMenu,
                ),
                const SizedBox(width: 8),
              ],
              bottom: TabBar(
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: context.appColors.textSecondary,
                indicatorColor: Theme.of(context).colorScheme.primary,
                indicatorWeight: 2,
                tabs: [
                  Tab(text: '${tabs[0]} (${downloading.length})'),
                  Tab(text: '${tabs[1]} (${completed.length})'),
                  Tab(text: '${tabs[2]} (${failed.length})'),
                ],
              ),
            ),
            body: Column(
              children: [
                DownloadSummaryCard(
                  downloading: manager.downloadingCount,
                  queued: manager.activeCount - manager.downloadingCount,
                  completed: completed.length,
                  totalSpeed: manager.totalSpeed,
                  activeTasks: active,
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildTaskList(downloading, 0),
                      _buildTaskList(completed, 1),
                      _buildTaskList(failed, 2),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<DownloadTask> _inProgressTasks(List<DownloadTask> tasks) => tasks
      .where((t) =>
          t.status == DownloadStatus.downloading ||
          t.status == DownloadStatus.waiting ||
          t.status == DownloadStatus.paused)
      .toList();

  Widget _buildTaskList(List<DownloadTask> tasks, int tab) {
    if (tasks.isEmpty) return _emptyTab(tab);
    final manager = ref.read(downloadManagerProvider).manager;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: tasks.length,
      itemBuilder: (context, i) {
        final task = tasks[i];
        return DownloadTaskCard(
          task: task,
          onPause: () => manager.pause(task.id),
          onResume: () => manager.resume(task.id),
          onRemove: ({required bool deleteFile}) {
            manager.remove(task.id, deleteFile: deleteFile);
          },
        );
      },
    );
  }

  Widget _emptyTab(int tab) {
    final (icon, title, subtitle) = switch (tab) {
      1 => (
          Icons.check_circle_outline,
          tr('没有已完成的下载'),
          tr('下载完成后会显示在这里，可在此直接打开文件')
        ),
      2 => (Icons.error_outline, tr('没有下载失败的任务'), tr('失败的任务可在这里重试或删除')),
      _ => (Icons.download_outlined, tr('暂无下载中的任务'), tr('选中文件后点「下载」即可加入队列')),
    };
    return EmptyView(icon: icon, title: title, subtitle: subtitle);
  }

  /// 右上角更多菜单：与 App 其他悬浮窗一致的样式与弹出方式。
  Future<void> _openMoreMenu() async {
    final action = await showAppPopup<DownloadsMenuAction>(
      context: context,
      anchorKey: _moreKey,
      builder: (_) => const DownloadsMenuPopup(),
    );
    if (!mounted || action == null) return;
    _handleMenuAction(action);
  }

  void _handleMenuAction(DownloadsMenuAction action) {
    final manager = ref.read(downloadManagerProvider).manager;
    switch (action) {
      case DownloadsMenuAction.resumeAll:
        manager.resumeAll();
        break;
      case DownloadsMenuAction.pauseAll:
        manager.pauseAll();
        break;
      case DownloadsMenuAction.clearCompleted:
        _confirmClearCompleted();
        break;
      case DownloadsMenuAction.downloadSettings:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsPage()),
        );
        break;
    }
  }

  Future<void> _confirmClearCompleted() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('清空已完成')),
        content: Text(tr('将删除全部已完成的下载记录，已下载的文件会保留。')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(tr('取消')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(tr('确定清空')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(downloadManagerProvider).manager.clearCompleted();
    }
  }
}
