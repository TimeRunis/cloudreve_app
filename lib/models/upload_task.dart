import 'dart:math';

/// 上传任务状态。
enum UploadStatus { waiting, uploading, paused, completed, failed }

UploadStatus uploadStatusFromString(String value) {
  for (final s in UploadStatus.values) {
    if (s.name == value) return s;
  }
  return UploadStatus.paused;
}

/// Cloudreve v4 创建上传会话的响应。
class UploadSession {
  final String sessionId;
  final String uploadId;
  final int chunkSize;
  final int expires;
  final List<String> uploadUrls;
  final String? credential;
  final String? completeURL;
  final String? storagePolicyType;
  final bool relay;
  final String? callbackSecret;
  final String? mimeType;
  final String? uploadPolicy;
  final String? uri;

  const UploadSession({
    required this.sessionId,
    required this.uploadId,
    required this.chunkSize,
    required this.expires,
    this.uploadUrls = const [],
    this.credential,
    this.completeURL,
    this.storagePolicyType,
    this.relay = false,
    this.callbackSecret,
    this.mimeType,
    this.uploadPolicy,
    this.uri,
  });

  factory UploadSession.fromJson(Map<String, dynamic> json) {
    final storagePolicy = json['storage_policy'];
    final policyType = storagePolicy is Map
        ? storagePolicy['type'] as String?
        : null;
    final relay = storagePolicy is Map
        ? (storagePolicy['relay'] as bool? ?? false)
        : false;
    return UploadSession(
      sessionId: json['session_id'] as String? ?? '',
      uploadId: json['upload_id'] as String? ?? '',
      chunkSize: (json['chunk_size'] as num?)?.toInt() ?? 0,
      expires: (json['expires'] as num?)?.toInt() ?? 0,
      uploadUrls: (json['upload_urls'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
      credential: json['credential'] as String?,
      completeURL: json['completeURL'] as String?,
      storagePolicyType: policyType,
      relay: relay,
      callbackSecret: json['callback_secret'] as String?,
      mimeType: json['mime_type'] as String?,
      uploadPolicy: json['upload_policy'] as String?,
      uri: json['uri'] as String?,
    );
  }
}

/// 一个上传任务（可 JSON 持久化，用于断点续传）。
class UploadTask {
  final String id;
  final String siteId;
  final String localPath;
  final String fileName;
  final String targetDirUri;
  final String targetUri;
  final int totalSize;
  final int lastModified;
  final String? mimeType;
  final int uploadedBytes;
  final int speed;
  final UploadStatus status;

  /// 断点续传所需的会话信息。
  final String? sessionId;
  final int chunkSize;
  final int expires;
  final int uploadedChunks;
  final String? uploadUrl;
  final String? credential;
  final String storageType;
  final bool relay;
  final String? callbackSecret;

  /// 当前使用的上传策略 id（local / onedrive / remote_chunk / ...）。
  final String strategyId;

  final DateTime createdAt;
  final String? error;

  const UploadTask({
    required this.id,
    required this.siteId,
    required this.localPath,
    required this.fileName,
    required this.targetDirUri,
    required this.targetUri,
    required this.totalSize,
    required this.lastModified,
    this.mimeType,
    required this.uploadedBytes,
    required this.speed,
    required this.status,
    this.sessionId,
    required this.chunkSize,
    required this.expires,
    required this.uploadedChunks,
    this.uploadUrl,
    this.credential,
    this.storageType = '',
    this.relay = false,
    this.callbackSecret,
    this.strategyId = '',
    required this.createdAt,
    this.error,
  });

  bool get isActive =>
      status == UploadStatus.waiting || status == UploadStatus.uploading;

  double get progress => totalSize <= 0
      ? 0
      : (uploadedBytes / totalSize).clamp(0.0, 1.0).toDouble();

  String get statusLabel => switch (status) {
        UploadStatus.waiting => '排队中',
        UploadStatus.uploading => '上传中',
        UploadStatus.paused => '已暂停',
        UploadStatus.completed => '已完成',
        UploadStatus.failed => '上传失败',
      };

  int get bytesLeft => totalSize - uploadedBytes;

  UploadTask copyWith({
    int? uploadedBytes,
    int? speed,
    UploadStatus? status,
    String? sessionId,
    int? chunkSize,
    int? expires,
    int? uploadedChunks,
    String? uploadUrl,
    String? credential,
    String? storageType,
    bool? relay,
    String? callbackSecret,
    String? strategyId,
    String? error,
    bool clearError = false,
  }) =>
      UploadTask(
        id: id,
        siteId: siteId,
        localPath: localPath,
        fileName: fileName,
        targetDirUri: targetDirUri,
        targetUri: targetUri,
        totalSize: totalSize,
        lastModified: lastModified,
        mimeType: mimeType,
        uploadedBytes: uploadedBytes ?? this.uploadedBytes,
        speed: speed ?? this.speed,
        status: status ?? this.status,
        sessionId: sessionId ?? this.sessionId,
        chunkSize: chunkSize ?? this.chunkSize,
        expires: expires ?? this.expires,
        uploadedChunks: uploadedChunks ?? this.uploadedChunks,
        uploadUrl: uploadUrl ?? this.uploadUrl,
        credential: credential ?? this.credential,
        storageType: storageType ?? this.storageType,
        relay: relay ?? this.relay,
        callbackSecret: callbackSecret ?? this.callbackSecret,
        strategyId: strategyId ?? this.strategyId,
        createdAt: createdAt,
        error: clearError ? null : (error ?? this.error),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'site_id': siteId,
        'local_path': localPath,
        'file_name': fileName,
        'target_dir_uri': targetDirUri,
        'target_uri': targetUri,
        'total_size': totalSize,
        'last_modified': lastModified,
        'mime_type': mimeType,
        'uploaded_bytes': uploadedBytes,
        'status': status.name,
        'session_id': sessionId,
        'chunk_size': chunkSize,
        'expires': expires,
        'uploaded_chunks': uploadedChunks,
        'upload_url': uploadUrl,
        'credential': credential,
        'storage_type': storageType,
        'relay': relay,
        'callback_secret': callbackSecret,
        'strategy_id': strategyId,
        'created_at': createdAt.toIso8601String(),
        'error': error,
      };

  factory UploadTask.fromJson(Map<String, dynamic> json) => UploadTask(
        id: json['id'] as String? ?? '',
        siteId: json['site_id'] as String? ?? '',
        localPath: json['local_path'] as String? ?? '',
        fileName: json['file_name'] as String? ?? '',
        targetDirUri: json['target_dir_uri'] as String? ?? '',
        targetUri: json['target_uri'] as String? ?? '',
        totalSize: (json['total_size'] as num?)?.toInt() ?? 0,
        lastModified: (json['last_modified'] as num?)?.toInt() ?? 0,
        mimeType: json['mime_type'] as String?,
        uploadedBytes: (json['uploaded_bytes'] as num?)?.toInt() ?? 0,
        speed: 0,
        status: uploadStatusFromString(json['status'] as String? ?? ''),
        sessionId: json['session_id'] as String?,
        chunkSize: (json['chunk_size'] as num?)?.toInt() ?? 0,
        expires: (json['expires'] as num?)?.toInt() ?? 0,
        uploadedChunks: (json['uploaded_chunks'] as num?)?.toInt() ?? 0,
        uploadUrl: json['upload_url'] as String?,
        credential: json['credential'] as String?,
        storageType: json['storage_type'] as String? ?? '',
        relay: json['relay'] as bool? ?? false,
        callbackSecret: json['callback_secret'] as String?,
        strategyId: json['strategy_id'] as String? ?? '',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
        error: json['error'] as String?,
      );

  static String newId() {
    final rand = Random().nextInt(0xFFFF);
    return '${DateTime.now().microsecondsSinceEpoch}-$rand';
  }
}

/// 生成上传目标文件 URI：目录 URI + URL 编码后的文件名。
String buildTargetFileUri(String dirUri, String fileName) {
  final dir = dirUri.endsWith('/') ? dirUri : '$dirUri/';
  return '$dir${Uri.encodeComponent(fileName)}';
}