import 'package:flutter/material.dart';

import '../core/network/cloudreve_api.dart';
import '../core/theme/app_colors.dart';
import '../models/file_item.dart';
import 'file_icon.dart';
import 'file_thumbnail.dart';

/// 文件详情底部面板（纯展示组件）。
class FileInfoSheet extends StatelessWidget {
  final FileItem file;
  final CloudreveApi? api;

  const FileInfoSheet({super.key, required this.file, this.api});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FileThumbnail(file: file, size: 40, api: api),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(file.name,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _row(context, '类型', file.isFolder ? '文件夹' : '文件'),
            if (!file.isFolder) _row(context, '大小', formatSize(file.size)),
            _row(context, '路径', file.relativePath),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 72,
              child: Text(k,
                  style: TextStyle(color: context.appColors.textMuted))),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}
