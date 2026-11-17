import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../core/theme/app_colors.dart';
import '../../models/download_task.dart';
import '../file/file_icon.dart';

/// 任务缩略图：已完成且文件存在时显示图片/视频缩略图，其余显示类型图标。
class DownloadTaskThumbnail extends StatelessWidget {
  final DownloadTask task;

  const DownloadTaskThumbnail({super.key, required this.task});

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
      '.png',
      '.jpg',
      '.jpeg',
      '.gif',
      '.webp',
      '.bmp',
      '.heic',
      '.heif',
      '.mp4',
      '.mkv',
      '.avi',
      '.mov',
      '.webm',
      '.m4v',
      '.ts',
      '.mp3',
      '.flac',
      '.wav',
      '.m4a',
      '.zip',
      '.rar',
      '.7z',
      '.tar',
      '.gz',
      '.pdf',
      '.doc',
      '.docx',
      '.xls',
      '.xlsx',
      '.ppt',
      '.pptx',
      '.txt',
      '.md',
      '.csv',
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
        errorBuilder: (_, __, ___) => Icon(Icons.movie_outlined,
            size: 22, color: context.appColors.textSecondary),
      );
    }
    return Icon(Icons.movie_outlined,
        size: 22, color: context.appColors.textSecondary);
  }
}
