import 'package:flutter/material.dart';

import '../models/file_item.dart';

/// 是否尝试加载缩略图（图片 / 视频）。
bool hasThumbnail(FileItem f) {
  if (f.isFolder) return false;
  final name = f.name.toLowerCase();
  const exts = [
    '.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp', '.heic', '.heif',
    '.mp4', '.mkv', '.avi', '.mov', '.webm', '.m4v', '.ts',
  ];
  return exts.any(name.endsWith);
}

/// 是否为图片文件（用于图片浏览）。
bool isImage(FileItem f) {
  if (f.isFolder) return false;
  return _isImage(f.name.toLowerCase());
}

/// 根据文件名返回合适的图标。
IconData fileIcon(FileItem f) {
  if (f.isFolder) return Icons.folder;
  final name = f.name.toLowerCase();
  if (name.endsWith('.mp4') ||
      name.endsWith('.mkv') ||
      name.endsWith('.avi') ||
      name.endsWith('.mov') ||
      name.endsWith('.webm')) {
    return Icons.movie_outlined;
  }
  if (name.endsWith('.mp3') ||
      name.endsWith('.flac') ||
      name.endsWith('.wav') ||
      name.endsWith('.m4a')) {
    return Icons.music_note_outlined;
  }
  if (name.endsWith('.png') ||
      name.endsWith('.jpg') ||
      name.endsWith('.jpeg') ||
      name.endsWith('.gif') ||
      name.endsWith('.webp') ||
      name.endsWith('.bmp')) {
    return Icons.image_outlined;
  }
  if (name.endsWith('.zip') ||
      name.endsWith('.rar') ||
      name.endsWith('.7z') ||
      name.endsWith('.tar') ||
      name.endsWith('.gz')) {
    return Icons.folder_zip_outlined;
  }
  if (name.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
  if (name.endsWith('.doc') || name.endsWith('.docx') || name.endsWith('.txt')) {
    return Icons.description_outlined;
  }
  return Icons.insert_drive_file_outlined;
}

/// 选中标记：蓝色圆点 + 白色对勾（选中后替换原文件/文件夹图标）。
class SelectionCheck extends StatelessWidget {
  final double size;

  const SelectionCheck({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(Icons.check, size: size * 0.7, color: Colors.white),
    );
  }
}

/// 文件图标 + 颜色。图片/视频固定为红色（不受主题影响）。
Color fileIconColor(BuildContext context, FileItem f) {
  if (f.isFolder) return Colors.amber.shade700;
  final name = f.name.toLowerCase();
  if (_isImage(name) || _isVideo(name)) return const Color(0xFFD50000);
  if (name.endsWith('.pdf')) return Colors.red.shade400;
  return Theme.of(context).colorScheme.onSurfaceVariant;
}

bool _isImage(String name) =>
    name.endsWith('.png') ||
    name.endsWith('.jpg') ||
    name.endsWith('.jpeg') ||
    name.endsWith('.gif') ||
    name.endsWith('.webp') ||
    name.endsWith('.bmp') ||
    name.endsWith('.heic') ||
    name.endsWith('.heif');

bool _isVideo(String name) =>
    name.endsWith('.mp4') ||
    name.endsWith('.mkv') ||
    name.endsWith('.avi') ||
    name.endsWith('.mov') ||
    name.endsWith('.webm') ||
    name.endsWith('.m4v') ||
    name.endsWith('.ts');

/// 格式化文件大小。
String formatSize(int bytes) {
  if (bytes <= 0) return '';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var i = 0;
  while (size >= 1024 && i < units.length - 1) {
    size /= 1024;
    i++;
  }
  return '${size.toStringAsFixed(size >= 100 ? 0 : 1)} ${units[i]}';
}
