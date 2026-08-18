import 'package:dio/dio.dart';

import '../../models/upload_task.dart';
import '../network/cloudreve_api.dart';

/// 上传策略接口。
///
/// 每一种 Cloudreve 存储策略（local / onedrive / s3 / oss / cos / ...）
/// 都可以实现为一个 [UploadStrategy]，在 [UploadManager] 中注册即可。
abstract class UploadStrategy {
  /// 策略唯一 id，会持久化到 [UploadTask.strategyId] 中。
  String get id;

  /// 当前任务是否由该策略处理。
  bool canHandle(UploadTask task);

  /// 上传一个分片。
  Future<void> uploadChunk({
    required CloudreveApi api,
    required UploadTask task,
    required int index,
    required List<int> bytes,
    required int chunkSize,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  });

  /// 所有分片上传完成后调用；不需要额外完成步骤的策略保持空实现。
  Future<void> completeUpload({
    required CloudreveApi api,
    required UploadTask task,
  }) async {}
}

/// 本地存储 / relay 代理上传。
///
/// Cloudreve 文档说明：local 存储策略，或任意存储策略的 `relay=true` 时，
/// 分片走 Cloudreve 自身接口 `POST /file/upload/{sessionId}/{index}`。
class LocalUploadStrategy extends UploadStrategy {
  @override
  String get id => 'local';

  @override
  bool canHandle(UploadTask task) {
    if (task.relay) return true;
    if (task.storageType.isEmpty) return true;
    final url = task.uploadUrl;
    return url == null || url.isEmpty;
  }

  @override
  Future<void> uploadChunk({
    required CloudreveApi api,
    required UploadTask task,
    required int index,
    required List<int> bytes,
    required int chunkSize,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    await api.uploadChunk(
      sessionId: task.sessionId!,
      index: index,
      bytes: bytes,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
    );
  }
}

/// OneDrive 可恢复上传会话。
///
/// 分片使用 `PUT` 发送到 OneDrive 的 upload session URL，
/// 每个分片必须带 `Content-Range` 头。
/// 所有分片传完后调用 Cloudreve 的 OneDrive 完成回调。
class OneDriveUploadStrategy extends UploadStrategy {
  @override
  String get id => 'onedrive';

  @override
  bool canHandle(UploadTask task) {
    if (task.relay) return false;
    if (task.storageType != 'onedrive') return false;
    final url = task.uploadUrl;
    return url != null && url.isNotEmpty;
  }

  @override
  Future<void> uploadChunk({
    required CloudreveApi api,
    required UploadTask task,
    required int index,
    required List<int> bytes,
    required int chunkSize,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    final url = task.uploadUrl!;
    final start = index * chunkSize;
    final end = start + bytes.length - 1;
    final headers = <String, String>{
      'Content-Type': 'application/octet-stream',
      'Content-Range': 'bytes $start-$end/${task.totalSize}',
      'Content-Length': '${bytes.length}',
    };
    if (task.credential != null && task.credential!.isNotEmpty) {
      headers['Authorization'] = task.credential!;
    }

    await api.dio.put(
      url,
      data: bytes,
      options: Options(
        headers: headers,
        sendTimeout: const Duration(minutes: 10),
        receiveTimeout: const Duration(minutes: 5),
      ),
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
    );
  }

  @override
  Future<void> completeUpload({
    required CloudreveApi api,
    required UploadTask task,
  }) async {
    final key = task.callbackSecret ?? '';
    if (key.isEmpty) {
      throw Exception('OneDrive 上传缺少回调 key');
    }
    await api.completeOneDriveUpload(
      sessionId: task.sessionId!,
      key: key,
    );
  }
}

/// 通用远程分片策略。
///
/// 适用于把分片直传到第三方存储、并通过 URL query `chunk` 指定分片序号的
/// 远程存储策略。后续如需支持 S3/OSS/COS 等专属协议，建议再新增独立策略。
class RemoteChunkUploadStrategy extends UploadStrategy {
  @override
  String get id => 'remote_chunk';

  @override
  bool canHandle(UploadTask task) {
    if (task.relay) return false;
    // 已有专用协议的存储策略不交给通用远程策略处理，避免被旧 strategyId 抢先匹配。
    const knownSpecific = {
      'onedrive',
      's3',
      'oss',
      'cos',
      'obs',
      'qiniu',
      'upyun',
    };
    if (knownSpecific.contains(task.storageType)) return false;
    final url = task.uploadUrl;
    return url != null && url.isNotEmpty;
  }

  @override
  Future<void> uploadChunk({
    required CloudreveApi api,
    required UploadTask task,
    required int index,
    required List<int> bytes,
    required int chunkSize,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    final uploadUrl = task.uploadUrl!;
    final base = Uri.parse(uploadUrl);
    final query = Map<String, String>.from(base.queryParameters);
    query['chunk'] = '$index';
    final url = base.replace(queryParameters: query).toString();
    final headers = <String, String>{
      'Content-Type': 'application/octet-stream',
      'Content-Length': '${bytes.length}',
    };
    if (task.credential != null && task.credential!.isNotEmpty) {
      headers['Authorization'] = task.credential!;
    }

    await api.dio.post(
      url,
      data: bytes,
      options: Options(
        headers: headers,
        sendTimeout: const Duration(minutes: 10),
        receiveTimeout: const Duration(minutes: 5),
      ),
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
    );
  }
}