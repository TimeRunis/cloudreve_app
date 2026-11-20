import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format/date_time.dart';
import '../core/theme/app_colors.dart';
import '../models/file_item.dart';
import '../providers/api_provider.dart';
import '../widgets/common/confirm_dialog.dart';
import '../widgets/common/empty_view.dart';
import '../widgets/common/error_view.dart';
import '../widgets/trash/trash_detail_sheet.dart';
import '../widgets/trash/trash_item.dart';
import '../core/i18n/app_localizations.dart';

/// 回收站页面：展示回收站文件，支持恢复和彻底删除。
class TrashPage extends ConsumerStatefulWidget {
  const TrashPage({super.key});

  @override
  ConsumerState<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends ConsumerState<TrashPage> {
  late Future<List<FileItem>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = ref
        .read(apiProvider)
        .listFiles('cloudreve://trash', pageSize: 500)
        .then(_newestFirst);
  }

  /// 最近进回收站的排最前（按 updated_at，缺失时回退 created_at）。
  List<FileItem> _newestFirst(DirectoryListing listing) {
    final files = [...listing.files];
    files.sort(
      (a, b) => compareNewestFirst(trashTimestamp(a), trashTimestamp(b)),
    );
    return files;
  }

  void _reload() {
    setState(_load);
  }

  /// 点击条目查看详情（完整原位置可复制）。
  void _showDetail(FileItem item) {
    final path = trashOriginalPath(item);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => TrashDetailSheet(
        item: item,
        onCopyPath: () {
          Clipboard.setData(ClipboardData(text: path));
          Navigator.of(sheetContext).pop();
          _toast(tr('原位置已复制'));
        },
      ),
    );
  }

  Future<void> _restore(FileItem item) async {
    final confirmed = await showConfirmDialog(
      context,
      title: tr('恢复文件'),
      message:
          tr('确定将「{name}」恢复到原位置吗？', args: {'name': trashDisplayName(item)}),
      actionLabel: tr('恢复'),
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(apiProvider).restoreFiles(uris: [item.path]);
      if (!mounted) return;
      _toast(tr('已恢复'));
      _reload();
    } catch (e) {
      print('[TrashPage] 恢复失败: $e');
      if (mounted) _toast(tr('恢复失败，请重试'));
    }
  }

  Future<void> _deleteForever(FileItem item) async {
    final confirmed = await showConfirmDialog(
      context,
      title: tr('彻底删除'),
      message: tr('确定彻底删除「{name}」吗？此操作不可恢复。',
          args: {'name': trashDisplayName(item)}),
      actionLabel: tr('彻底删除'),
      danger: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(apiProvider).deleteFiles(
        uris: [item.path],
        skipSoftDelete: true,
      );
      if (!mounted) return;
      _toast(tr('已彻底删除'));
      _reload();
    } catch (e) {
      print('[TrashPage] 彻底删除失败: $e');
      if (mounted) _toast(tr('删除失败，请重试'));
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.contentBg,
      appBar: AppBar(
        backgroundColor: context.appColors.headerBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: tr('返回'),
          icon: Icon(Icons.close,
              size: 18, color: context.appColors.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          tr('回收站'),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: context.appColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: tr('刷新'),
            icon: Icon(Icons.refresh,
                size: 20, color: context.appColors.textSecondary),
            onPressed: _reload,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<List<FileItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorView(
                message:
                    tr('加载失败：{error}', args: {'error': '${snapshot.error}'}));
          }
          final files = snapshot.data ?? const <FileItem>[];
          if (files.isEmpty) {
            return EmptyView(
              icon: Icons.delete_outline,
              iconSize: 48,
              title: tr('回收站是空的'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final item = files[index];
              return TrashItem(
                item: item,
                onTap: () => _showDetail(item),
                onRestore: () => _restore(item),
                onDelete: () => _deleteForever(item),
              );
            },
          );
        },
      ),
    );
  }
}
