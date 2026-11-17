import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../models/file_item.dart';
import '../providers/api_provider.dart';
import '../widgets/common/confirm_dialog.dart';
import '../widgets/common/empty_view.dart';
import '../widgets/common/error_view.dart';
import '../widgets/trash/trash_item.dart';

/// 回收站页面：展示回收站文件，支持恢复和彻底删除。
class TrashPage extends ConsumerStatefulWidget {
  const TrashPage({super.key});

  @override
  ConsumerState<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends ConsumerState<TrashPage> {
  late Future<DirectoryListing> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future =
        ref.read(apiProvider).listFiles('cloudreve://trash', pageSize: 500);
  }

  void _reload() {
    setState(_load);
  }

  Future<void> _restore(FileItem item) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '恢复文件',
      message: '确定将「${trashDisplayName(item)}」恢复到原位置吗？',
      actionLabel: '恢复',
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(apiProvider).restoreFiles(uris: [item.path]);
      if (!mounted) return;
      _toast('已恢复');
      _reload();
    } catch (e) {
      print('[TrashPage] 恢复失败: $e');
      if (mounted) _toast('恢复失败，请重试');
    }
  }

  Future<void> _deleteForever(FileItem item) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '彻底删除',
      message: '确定彻底删除「${trashDisplayName(item)}」吗？此操作不可恢复。',
      actionLabel: '彻底删除',
      danger: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(apiProvider).deleteFiles(
        uris: [item.path],
        skipSoftDelete: true,
      );
      if (!mounted) return;
      _toast('已彻底删除');
      _reload();
    } catch (e) {
      print('[TrashPage] 彻底删除失败: $e');
      if (mounted) _toast('删除失败，请重试');
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
          tooltip: '返回',
          icon: Icon(Icons.close,
              size: 18, color: context.appColors.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '回收站',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: context.appColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: Icon(Icons.refresh,
                size: 20, color: context.appColors.textSecondary),
            onPressed: _reload,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<DirectoryListing>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorView(message: '加载失败：${snapshot.error}');
          }
          final files = snapshot.data?.files ?? const <FileItem>[];
          if (files.isEmpty) {
            return const EmptyView(
              icon: Icons.delete_outline,
              iconSize: 48,
              title: '回收站是空的',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: files.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: context.appColors.border),
            itemBuilder: (context, index) {
              final item = files[index];
              return TrashItem(
                item: item,
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
