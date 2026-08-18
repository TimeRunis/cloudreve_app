import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../models/file_item.dart';
import '../providers/api_provider.dart';
import '../widgets/file_icon.dart';

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
    _future = ref
        .read(apiProvider)
        .listFiles('cloudreve://trash', pageSize: 500);
  }

  void _reload() {
    setState(_load);
  }

  Future<void> _restore(FileItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复文件'),
        content: Text('确定将「${_displayName(item)}」恢复到原位置吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('彻底删除'),
        content: Text('确定彻底删除「${_displayName(item)}」吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('彻底删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
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

  String _displayName(FileItem item) {
    final uri = _restoreUri(item);
    if (uri.isNotEmpty) {
      final parsed = Uri.tryParse(uri);
      final segments = parsed?.pathSegments ?? const <String>[];
      if (segments.isNotEmpty) {
        return Uri.decodeComponent(segments.last);
      }
    }
    return item.name;
  }

  String _restoreUri(FileItem item) =>
      item.metadata['sys:restore_uri'] as String? ?? '';

  String _originalPath(FileItem item) {
    final uri = _restoreUri(item);
    if (uri.isEmpty) return item.path;
    const prefix = 'cloudreve://my';
    return uri.startsWith(prefix) ? uri.substring(prefix.length) : uri;
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
            return Center(
              child: Text(
                '加载失败：${snapshot.error}',
                style: TextStyle(color: context.appColors.textSecondary),
              ),
            );
          }
          final files = snapshot.data?.files ?? const <FileItem>[];
          if (files.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_outline,
                      size: 48, color: context.appColors.textMuted),
                  const SizedBox(height: 8),
                  Text('回收站是空的',
                      style: TextStyle(
                          fontSize: 14,
                          color: context.appColors.textSecondary)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: files.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: context.appColors.border),
            itemBuilder: (context, index) {
              final item = files[index];
              return ListTile(
                leading: Icon(
                  fileIconForName(_displayName(item)),
                  size: 28,
                  color: context.appColors.textSecondary,
                ),
                title: Text(
                  _displayName(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.appColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  '${formatSize(item.size)} · 原位置：${_originalPath(item)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appColors.textSecondary,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: '恢复',
                      icon: Icon(Icons.restore,
                          size: 20, color: context.appColors.textSecondary),
                      onPressed: () => _restore(item),
                    ),
                    IconButton(
                      tooltip: '彻底删除',
                      icon: Icon(Icons.delete_outline,
                          size: 20, color: context.appColors.textSecondary),
                      onPressed: () => _deleteForever(item),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}