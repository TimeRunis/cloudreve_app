import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../models/upload_task.dart';
import '../providers/settings_provider.dart';
import '../providers/upload_provider.dart';
import '../widgets/common/empty_view.dart';
import '../widgets/upload/upload_menu_popup.dart';
import '../widgets/upload/upload_queue_app_bar.dart';
import '../widgets/upload/upload_task_tile.dart';

/// 上传队列页面。
///
/// 外观参考 docs/style/10.html 与 11.html 的上传队列窗口：
/// 顶部为「上传队列」标题栏，任务行由 [UploadTaskTile] 渲染。
class UploadQueuePage extends ConsumerStatefulWidget {
  /// 点击「+」继续添加文件时上传到的目标目录 URI。
  final String targetDirUri;

  const UploadQueuePage({super.key, required this.targetDirUri});

  @override
  ConsumerState<UploadQueuePage> createState() => _UploadQueuePageState();
}

class _UploadQueuePageState extends ConsumerState<UploadQueuePage> {
  bool _hideCompleted = false;

  @override
  Widget build(BuildContext context) {
    final manager = ref.read(uploadManagerProvider).manager;

    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        final all = manager.tasks;
        final tasks = _hideCompleted
            ? all.where((t) => t.status != UploadStatus.completed).toList()
            : all;

        return Scaffold(
          backgroundColor: context.appColors.contentBg,
          appBar: UploadQueueAppBar(
            overwrite: manager.overwrite,
            hideCompleted: _hideCompleted,
            onClose: () => Navigator.of(context).pop(),
            onPickFiles: _pickFiles,
            onMenuSelected: _handleMenu,
          ),
          body: tasks.isEmpty
              ? const EmptyView(
                  icon: Icons.cloud_upload_outlined,
                  iconSize: 48,
                  title: '暂无上传任务',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return UploadTaskTile(
                      task: task,
                      onPause: () => manager.pause(task.id),
                      onResume: () => manager.resume(task.id),
                      onRemove: () => manager.remove(task.id),
                    );
                  },
                ),
        );
      },
    );
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform
        .pickFiles(allowMultiple: true, withData: false);
    if (result == null || !mounted) return;
    final paths = result.files.map((f) => f.path).whereType<String>().toList();
    if (paths.isEmpty) return;
    final site = ref.read(currentSiteProvider);
    if (site == null) return;
    await ref.read(uploadManagerProvider).manager.enqueueFiles(
          paths: paths,
          siteId: site.id,
          targetDirUri: widget.targetDirUri,
        );
  }

  void _handleMenu(UploadMenuAction action) {
    final manager = ref.read(uploadManagerProvider).manager;
    switch (action) {
      case UploadMenuAction.overwrite:
        manager.setOverwrite(!manager.overwrite);
        break;
      case UploadMenuAction.hideCompleted:
        setState(() => _hideCompleted = !_hideCompleted);
        break;
      case UploadMenuAction.retryAll:
        manager.retryAllFailed();
        break;
      case UploadMenuAction.clearCompleted:
        manager.clearCompleted();
        break;
    }
  }
}
