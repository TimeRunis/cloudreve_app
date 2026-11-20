import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../models/file_item.dart';
import '../network/cloudreve_api.dart';
import '../i18n/app_localizations.dart';

/// 一次图片下载：对外暴露进度与结果，可被多个页面共享。
class ImageTask {
  /// 缓存键（站点 + 文件完整 URI）。
  final String key;

  /// 下载进度 0..1；null 表示排队中或总大小未知。
  final ValueNotifier<double?> progress = ValueNotifier<double?>(null);

  /// 已完成的字节；未完成时为 null（命中缓存时立即有值）。
  Uint8List? bytes;

  final Completer<Uint8List> _completer = Completer<Uint8List>();

  ImageTask._(this.key);

  ImageTask._done(this.key, Uint8List value) : bytes = value {
    _completer.complete(value);
    progress.value = 1;
  }

  Future<Uint8List> get value => _completer.future;

  /// 是否已经拿到数据（缓存命中时为 true）。
  bool get isReady => bytes != null;
}

/// 单张图片的抓取函数，[onProgress] 用于回报下载进度。
typedef ImageFetch = Future<Uint8List> Function(ProgressCallback onProgress);

/// 图片字节加载器（全局单例）。
///
/// - 内存缓存（LRU，按字节封顶）：加载过的图片再次请求直接命中，不重新下载；
/// - 并发上限 [maxConcurrent]：超出的请求排队，不会一次性打满网络；
/// - 后台继续：任务由加载器持有，页面滑走/销毁不会中断已开始的下载，
///   下载完成后自动进入缓存，回到该页时直接显示。
class ImageLoader {
  ImageLoader({
    this.maxConcurrent = 5,
    this.maxCacheBytes = 128 * 1024 * 1024,
  });

  static final ImageLoader instance = ImageLoader();

  /// 同时下载的图片数量上限。
  final int maxConcurrent;

  /// 缓存总字节上限，超过后淘汰最久未使用的图片。
  final int maxCacheBytes;

  /// 按插入顺序保存缓存，末尾是最近使用的。
  final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap();

  int _cacheBytes = 0;

  final Map<String, ImageTask> _tasks = {};
  final Queue<_ImageJob> _queue = Queue();
  int _running = 0;

  /// 缓存代际：退出登录等场景自增，让旧缓存键整体失效。
  int _generation = 0;

  int get generation => _generation;

  /// 请求一张图片：命中缓存返回已完成的任务，否则返回进行中/排队中的任务。
  ///
  /// 同一个 [key] 的重复请求复用同一个任务，[fetch] 只对首次请求生效。
  ImageTask request(String key, ImageFetch fetch) {
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached; // 重新插入队尾，刷新 LRU 顺序
      return ImageTask._done(key, cached);
    }
    final existing = _tasks[key];
    if (existing != null) return existing;

    final task = ImageTask._(key);
    _tasks[key] = task;
    // 预取等场景没人接收错误，挂一个空处理器避免冒泡到 zone。
    task.value.then((_) {}, onError: (Object _) {});
    _queue.add(_ImageJob(task, fetch));
    _pump();
    return task;
  }

  /// 当前缓存了多少字节（调试用）。
  int get cachedBytes => _cacheBytes;

  /// 清空缓存并换代：退出登录后不会把上一个账号的图片给下一个账号。
  void clear() {
    _cache.clear();
    _cacheBytes = 0;
    _generation++;
  }

  void _pump() {
    while (_running < maxConcurrent && _queue.isNotEmpty) {
      final job = _queue.removeFirst();
      _running++;
      unawaited(_run(job));
    }
  }

  Future<void> _run(_ImageJob job) async {
    final task = job.task;
    try {
      final bytes = await job.fetch((received, total) {
        if (total > 0) task.progress.value = received / total;
      });
      if (bytes.isEmpty) throw StateError(tr('图片内容为空'));
      _store(task.key, bytes);
      task.bytes = bytes;
      task._completer.complete(bytes);
    } catch (error, stackTrace) {
      task._completer.completeError(error, stackTrace);
    } finally {
      _tasks.remove(task.key);
      _running--;
      _pump();
    }
  }

  void _store(String key, Uint8List bytes) {
    final old = _cache.remove(key);
    if (old != null) _cacheBytes -= old.length;
    _cache[key] = bytes;
    _cacheBytes += bytes.length;
    while (_cacheBytes > maxCacheBytes && _cache.length > 1) {
      final oldestKey = _cache.keys.first;
      _cacheBytes -= _cache.remove(oldestKey)!.length;
    }
  }
}

class _ImageJob {
  final ImageTask task;
  final ImageFetch fetch;

  const _ImageJob(this.task, this.fetch);
}

/// 图片缓存的唯一键：代际 + 站点地址 + 文件完整 URI（分享内路径已含分享 ID）。
String imageCacheKey(CloudreveApi api, FileItem file) =>
    '${ImageLoader.instance.generation}|'
    '${api.site?.normalizedBaseUrl ?? ''}|${file.path}';

/// 取 Cloudreve 原图字节的抓取函数（先换直链，再按进度下载）。
ImageFetch cloudreveImageFetch(CloudreveApi api, String path) {
  return (onProgress) async {
    final url = await api.getFileSourceUrl(path);
    if (url == null || url.isEmpty) {
      throw StateError(tr('获取图片地址失败'));
    }
    final response = await api.dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
      onReceiveProgress: onProgress,
    );
    final data = response.data;
    if (data == null || data.isEmpty) throw StateError(tr('图片内容为空'));
    return Uint8List.fromList(data);
  };
}

/// 请求一张 Cloudreve 图片（命中缓存立即完成）。
ImageTask requestCloudreveImage(CloudreveApi api, FileItem file) =>
    ImageLoader.instance.request(
      imageCacheKey(api, file),
      cloudreveImageFetch(api, file.path),
    );
