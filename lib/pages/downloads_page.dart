import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../core/download/download_manager.dart';
import '../core/theme/app_colors.dart';
import '../models/download_task.dart';
import '../providers/download_provider.dart';
import '../widgets/file_icon.dart';
import '../widgets/popup_item.dart';
import 'settings_page.dart';

enum _DownloadsMenuAction {
  resumeAll,
  pauseAll,
  clearCompleted,
  downloadSettings,
}

enum _DetailAction { deleteRecord, deleteTaskAndFile }

/// 下载页面：下载中 / 已完成 / 下载失败三个分类。
class DownloadsPage extends ConsumerStatefulWidget {
  const DownloadsPage({super.key});

  @override
  ConsumerState<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends ConsumerState<DownloadsPage> {
  static const _tabs = ['下载中', '已完成', '下载失败'];

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(downloadManagerProvider).manager;
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

        return DefaultTabController(
          length: _tabs.length,
          child: Scaffold(
            backgroundColor: context.appColors.contentBg,
            appBar: AppBar(
              backgroundColor: context.appColors.headerBg,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                tooltip: '返回',
                icon:
                    Icon(Icons.arrow_back, color: context.appColors.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text('下载',
                  style: TextStyle(color: context.appColors.textPrimary)),
              actions: [
                IconButton(
                  tooltip: '更多操作',
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
                  Tab(text: '${_tabs[0]} (${downloading.length})'),
                  Tab(text: '${_tabs[1]} (${completed.length})'),
                  Tab(text: '${_tabs[2]} (${failed.length})'),
                ],
              ),
            ),
            body: Column(
              children: [
                _SummaryCard(manager: manager),
                Expanded(
                  child: TabBarView(
                    children: [
                      _TaskList(manager: manager, tasks: downloading, tab: 0),
                      _TaskList(manager: manager, tasks: completed, tab: 1),
                      _TaskList(manager: manager, tasks: failed, tab: 2),
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

  /// 右上角更多菜单：与 App 其他悬浮窗一致的样式与弹出方式。
  void _openMoreMenu() {
    final topPad = MediaQuery.of(context).padding.top;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'downloads-menu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              top: topPad + kToolbarHeight + kTextTabBarHeight + 8,
              right: 8,
              child: _DownloadsMenuPopup(
                onAction: (action) {
                  Navigator.of(context).pop();
                  _handleMenuAction(action);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleMenuAction(_DownloadsMenuAction action) {
    final manager = ref.read(downloadManagerProvider).manager;
    switch (action) {
      case _DownloadsMenuAction.resumeAll:
        manager.resumeAll();
        break;
      case _DownloadsMenuAction.pauseAll:
        manager.pauseAll();
        break;
      case _DownloadsMenuAction.clearCompleted:
        _confirmClearCompleted();
        break;
      case _DownloadsMenuAction.downloadSettings:
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
        title: const Text('清空已完成'),
        content: const Text('将删除全部已完成的下载记录，已下载的文件会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确定清空'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(downloadManagerProvider).manager.clearCompleted();
    }
  }
}

/// 与 MoreMenuPopup / UserMenuPopup 风格一致的下载页悬浮菜单。
class _DownloadsMenuPopup extends StatelessWidget {
  final ValueChanged<_DownloadsMenuAction> onAction;

  const _DownloadsMenuPopup({required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 8,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.45,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PopupItem(
              icon: Icons.play_arrow_rounded,
              label: '全部开始',
              onTap: () => onAction(_DownloadsMenuAction.resumeAll),
            ),
            PopupItem(
              icon: Icons.pause_rounded,
              label: '全部暂停',
              onTap: () => onAction(_DownloadsMenuAction.pauseAll),
            ),
            PopupItem(
              icon: Icons.delete_sweep_outlined,
              label: '清空已完成',
              onTap: () => onAction(_DownloadsMenuAction.clearCompleted),
            ),
            Divider(height: 1, color: context.appColors.border),
            PopupItem(
              icon: Icons.settings_outlined,
              label: '下载设置',
              onTap: () => onAction(_DownloadsMenuAction.downloadSettings),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final DownloadManager manager;

  const _SummaryCard({required this.manager});

  @override
  Widget build(BuildContext context) {
    final tasks = manager.tasks;
    final active =
        tasks.where((t) => t.status != DownloadStatus.completed).toList();
    final totalBytes =
        active.fold<int>(0, (sum, t) => sum + t.totalSize);
    final doneBytes =
        active.fold<int>(0, (sum, t) => sum + t.downloadedBytes);
    final overall = totalBytes <= 0
        ? 0.0
        : (doneBytes / totalBytes).clamp(0.0, 1.0).toDouble();
    final completed =
        tasks.where((t) => t.status == DownloadStatus.completed).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _stat(context, '下载中', '${manager.downloadingCount}'),
              _divider(context),
              _stat(context, '排队中',
                  '${manager.activeCount - manager.downloadingCount}'),
              _divider(context),
              _stat(context, '总速度', formatSpeed(manager.totalSpeed)),
              _divider(context),
              _stat(context, '已完成', '$completed'),
            ],
          ),
          if (active.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: overall,
                minHeight: 5,
                color: Theme.of(context).colorScheme.primary,
                backgroundColor: context.appColors.surfaceMuted,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '总进度 ${(overall * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.appColors.textSecondary),
                ),
                const Spacer(),
                Text(
                  '${formatSize(doneBytes)} / ${formatSize(totalBytes)}',
                  style: TextStyle(
                      fontSize: 11, color: context.appColors.textMuted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.appColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: context.appColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) => Container(
        width: 1,
        height: 26,
        color: context.appColors.border,
      );
}

class _TaskList extends StatelessWidget {
  final DownloadManager manager;
  final List<DownloadTask> tasks;
  final int tab;

  const _TaskList({
    required this.manager,
    required this.tasks,
    required this.tab,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return _EmptyTab(tab: tab);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: tasks.length,
      itemBuilder: (context, i) =>
          _TaskCard(task: tasks[i], manager: manager),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final DownloadTask task;
  final DownloadManager manager;

  const _TaskCard({required this.task, required this.manager});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(context, task.status);
    final completed = task.status == DownloadStatus.completed;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TaskThumbnail(task: task),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.appColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration:
                              BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          task.status == DownloadStatus.downloading
                              ? '${task.statusLabel} · ${formatSpeed(task.speed)}'
                              : task.statusLabel,
                          style:
                              TextStyle(fontSize: 12, color: context.appColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      completed
                          ? formatSize(task.totalSize)
                          : '${formatSize(task.downloadedBytes)} / ${formatSize(task.totalSize)}'
                              ' · ${(task.progress * 100).toStringAsFixed(1)}%'
                              '${task.threadCount > 1 ? ' · ${task.threadCount}线程' : ''}',
                      style: TextStyle(
                          fontSize: 11, color: context.appColors.textMuted),
                    ),
                    if (task.status == DownloadStatus.failed &&
                        task.error != null &&
                        task.error!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '失败原因：${task.error}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => _showDetail(context),
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.info_outline,
                      size: 18, color: context.appColors.textMuted),
                ),
              ),
            ],
          ),
          if (!completed) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: task.progress,
                minHeight: 5,
                color: color,
                backgroundColor: context.appColors.surfaceMuted,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: _actions(context),
          ),
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context) {
    Widget button(String label, VoidCallback onTap, {Color? color}) {
      return TextButton(
        style: TextButton.styleFrom(
          foregroundColor: color ?? Theme.of(context).colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(56, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontSize: 13)),
      );
    }

    switch (task.status) {
      case DownloadStatus.downloading:
        return [
          button('暂停', () => manager.pause(task.id)),
          button(
              '取消',
              () => _confirmRemove(
                    context,
                    title: '取消任务',
                    message: '将停止下载并删除已下载的文件与临时文件，此操作不可恢复。',
                    actionLabel: '确定取消',
                    deleteFile: true,
                  ),
              color: context.appColors.textSecondary),
        ];
      case DownloadStatus.waiting:
        return [
          button(
              '取消',
              () => _confirmRemove(
                    context,
                    title: '取消任务',
                    message: '将删除排队任务及其临时文件，此操作不可恢复。',
                    actionLabel: '确定取消',
                    deleteFile: true,
                  ),
              color: context.appColors.textSecondary),
        ];
      case DownloadStatus.paused:
        return [
          button('继续', () => manager.resume(task.id)),
          button(
              '删除',
              () => _confirmRemove(
                    context,
                    title: '删除任务和文件',
                    message: '将删除任务、已下载的文件与临时文件，此操作不可恢复。',
                    actionLabel: '确定删除',
                    deleteFile: true,
                  ),
              color: context.appColors.textSecondary),
        ];
      case DownloadStatus.failed:
        return [
          button('重试', () => manager.resume(task.id)),
          button(
              '删除',
              () => _confirmRemove(
                    context,
                    title: '删除任务和文件',
                    message: '将删除任务、已下载的文件与临时文件，此操作不可恢复。',
                    actionLabel: '确定删除',
                    deleteFile: true,
                  ),
              color: context.appColors.textSecondary),
        ];
      case DownloadStatus.completed:
        return [
          button('打开', () => _openFile(context)),
          button(
              '删除记录',
              () => _confirmRemove(
                    context,
                    title: '删除记录',
                    message: '仅删除下载记录，已下载的文件会保留。',
                    actionLabel: '确定删除',
                    deleteFile: false,
                  ),
              color: context.appColors.textSecondary),
        ];
    }
  }

  Future<void> _confirmRemove(
    BuildContext context, {
    required String title,
    required String message,
    required String actionLabel,
    required bool deleteFile,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await manager.remove(task.id, deleteFile: deleteFile);
    }
  }

  Future<void> _showDetail(BuildContext context) async {
    final action = await showModalBottomSheet<_DetailAction>(
      context: context,
      backgroundColor: context.appColors.surface,
      builder: (_) => _TaskDetailSheet(task: task),
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case _DetailAction.deleteRecord:
        await _confirmRemove(
          context,
          title: '删除记录',
          message: '仅删除下载记录，已下载的文件会保留。',
          actionLabel: '确定删除',
          deleteFile: false,
        );
        break;
      case _DetailAction.deleteTaskAndFile:
        await _confirmRemove(
          context,
          title: '删除任务和文件',
          message: '将删除任务、已下载的文件与临时文件，此操作不可恢复。',
          actionLabel: '确定删除',
          deleteFile: true,
        );
        break;
    }
  }

  Future<void> _openFile(BuildContext context) async {
    if (!File(task.savePath).existsSync()) {
      _toast(context, '文件不存在，可能已被移动或删除');
      return;
    }
    try {
      final result = await OpenFilex.open(task.savePath);
      if (!context.mounted) return;
      if (result.type != ResultType.done) {
        _toast(context, '无法打开文件');
      }
    } catch (e) {
      if (!context.mounted) return;
      _toast(context, '无法打开文件');
    }
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

/// 任务详情：状态、失败原因、大小、线程、创建时间、保存路径与操作。
class _TaskDetailSheet extends StatelessWidget {
  final DownloadTask task;

  const _TaskDetailSheet({required this.task});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(context, task.status);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.appColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _row(
            context,
            '状态',
            task.status == DownloadStatus.failed
                ? '${task.statusLabel}${task.error == null ? '' : '（${task.error}）'}'
                : task.statusLabel,
            valueColor: color,
            dense: true,
          ),
          _row(
            context,
            '大小',
            '${formatSize(task.downloadedBytes)} / ${formatSize(task.totalSize)}'
                ' · ${(task.progress * 100).toStringAsFixed(1)}%',
          ),
          _row(context, '线程', '${task.threadCount}'),
          _row(
            context,
            '创建时间',
            '${task.createdAt.year}-${task.createdAt.month.toString().padLeft(2, '0')}-${task.createdAt.day.toString().padLeft(2, '0')} '
                '${task.createdAt.hour.toString().padLeft(2, '0')}:${task.createdAt.minute.toString().padLeft(2, '0')}',
          ),
          _row(context, '保存路径', task.savePath, dense: true),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary),
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: const Text('复制路径'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: task.savePath));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('路径已复制')));
                  }
                },
              ),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(
                    foregroundColor: context.appColors.textSecondary),
                onPressed: () =>
                    Navigator.of(context).pop(_DetailAction.deleteRecord),
                child: const Text('删除记录'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error),
                onPressed: () =>
                    Navigator.of(context).pop(_DetailAction.deleteTaskAndFile),
                child: const Text('删除任务和文件'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
    bool dense = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13, color: context.appColors.textMuted)),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: dense ? 3 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: valueColor ?? context.appColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 任务缩略图：已完成且文件存在时显示图片/视频缩略图，其余显示类型图标。
class _TaskThumbnail extends StatelessWidget {
  final DownloadTask task;

  const _TaskThumbnail({required this.task});

  @override
  Widget build(BuildContext context) {
    final completed = task.status == DownloadStatus.completed;
    final file = File(task.savePath);
    final Widget child;
    if (completed && file.existsSync()) {
      if (isImageFileName(task.name)) {
        child = Image.file(
          file,
          fit: BoxFit.cover,
          cacheWidth: 96,
          errorBuilder: (_, __, ___) => _TypeIcon(name: task.name),
        );
      } else if (isVideoFileName(task.name)) {
        child = _VideoThumbnail(path: task.savePath);
      } else {
        child = _TypeIcon(name: task.name);
      }
    } else {
      child = _TypeIcon(name: task.name);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 48,
        height: 48,
        color: context.appColors.surfaceMuted,
        child: SizedBox.expand(child: child),
      ),
    );
  }
}

/// 类型图标；未知扩展名显示带问号的文件图标。
class _TypeIcon extends StatelessWidget {
  final String name;

  const _TypeIcon({required this.name});

  @override
  Widget build(BuildContext context) {
    final lower = name.toLowerCase();
    final known = [
      '.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp', '.heic', '.heif',
      '.mp4', '.mkv', '.avi', '.mov', '.webm', '.m4v', '.ts',
      '.mp3', '.flac', '.wav', '.m4a',
      '.zip', '.rar', '.7z', '.tar', '.gz',
      '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt',
      '.md', '.csv',
    ];
    final unknown = !known.any(lower.endsWith);
    if (!unknown) {
      return Icon(fileIconForName(name),
          size: 22, color: context.appColors.textSecondary);
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.insert_drive_file_outlined,
            size: 22, color: context.appColors.textSecondary),
        Positioned(
          right: 10,
          bottom: 7,
          child: Container(
            width: 11,
            height: 11,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: const Text(
              '?',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 调用系统机制（MediaMetadataRetriever）生成本地视频缩略图。
class _VideoThumbnail extends StatefulWidget {
  final String path;

  const _VideoThumbnail({required this.path});

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  String? _thumbPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final temp = await getTemporaryDirectory();
      final dir = Directory('${temp.path}/cloudreve_thumbs');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final safeName = widget.path
          .split(Platform.pathSeparator)
          .last
          .replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
      final target = '${dir.path}/$safeName.jpg';
      if (await File(target).exists()) {
        if (mounted) setState(() => _thumbPath = target);
        return;
      }
      final generated = await VideoThumbnail.thumbnailFile(
        video: widget.path,
        thumbnailPath: target,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 160,
        quality: 60,
      );
      if (generated != null && mounted) {
        setState(() => _thumbPath = generated);
      }
    } catch (_) {
      // 生成失败时回退为视频类型图标。
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = _thumbPath;
    if (path != null) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.movie_outlined,
                size: 22, color: context.appColors.textSecondary),
      );
    }
    return Icon(Icons.movie_outlined,
        size: 22, color: context.appColors.textSecondary);
  }
}

class _EmptyTab extends StatelessWidget {
  final int tab;

  const _EmptyTab({required this.tab});

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (tab) {
      1 => (Icons.check_circle_outline, '没有已完成的下载', '下载完成后会显示在这里，可在此直接打开文件'),
      2 => (Icons.error_outline, '没有下载失败的任务', '失败的任务可在这里重试或删除'),
      _ => (Icons.download_outlined, '暂无下载中的任务', '选中文件后点「下载」即可加入队列'),
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: context.appColors.textMuted),
          const SizedBox(height: 12),
          Text(title,
              style: TextStyle(
                  fontSize: 15, color: context.appColors.textSecondary)),
          const SizedBox(height: 6),
          Text(subtitle,
              style:
                  TextStyle(fontSize: 12, color: context.appColors.textMuted)),
        ],
      ),
    );
  }
}

Color statusColor(BuildContext context, DownloadStatus status) {
  switch (status) {
    case DownloadStatus.downloading:
      return Theme.of(context).colorScheme.primary;
    case DownloadStatus.waiting:
      return context.appColors.textSecondary;
    case DownloadStatus.paused:
      return Colors.orange;
    case DownloadStatus.completed:
      return Colors.green;
    case DownloadStatus.failed:
      return Theme.of(context).colorScheme.error;
  }
}

String formatSpeed(int bytesPerSecond) =>
    bytesPerSecond <= 0 ? '—' : '${formatSize(bytesPerSecond)}/s';
