/// 下载任务状态。
enum DownloadStatus { waiting, downloading, paused, completed, failed }

DownloadStatus downloadStatusFromString(String value) {
  for (final s in DownloadStatus.values) {
    if (s.name == value) return s;
  }
  return DownloadStatus.paused;
}

/// 一个下载任务（可 JSON 持久化）。
class DownloadTask {
  final String id;
  final String fileId;

  /// 文件 URI（cloudreve://my/...），失败重试时用于重新获取直链。
  final String uri;

  final String name;
  final String url;
  final int totalSize;
  final int downloadedBytes;

  /// 运行期实时速度（字节/秒），不参与持久化。
  final int speed;

  final DownloadStatus status;
  final int threadCount;
  final DateTime createdAt;
  final String savePath;
  final String? error;

  const DownloadTask({
    required this.id,
    required this.fileId,
    required this.uri,
    required this.name,
    required this.url,
    required this.totalSize,
    required this.downloadedBytes,
    required this.speed,
    required this.status,
    required this.threadCount,
    required this.createdAt,
    required this.savePath,
    this.error,
  });

  /// 主临时文件（未完成时写入，完成后重命名为 [savePath]）。
  String get partPath => '$savePath.cldpart';

  /// 多线程分段临时文件。
  String segmentPartPath(int index) => '$partPath.seg$index';

  double get progress => totalSize <= 0
      ? 0
      : (downloadedBytes / totalSize).clamp(0.0, 1.0).toDouble();

  String get statusLabel => switch (status) {
        DownloadStatus.waiting => '排队中',
        DownloadStatus.downloading => '下载中',
        DownloadStatus.paused => '已暂停',
        DownloadStatus.completed => '已完成',
        DownloadStatus.failed => '下载失败',
      };

  bool get isActive =>
      status == DownloadStatus.downloading ||
      status == DownloadStatus.waiting;

  DownloadTask copyWith({
    DownloadStatus? status,
    int? downloadedBytes,
    int? speed,
    int? threadCount,
    String? url,
    String? error,
    bool clearError = false,
  }) =>
      DownloadTask(
        id: id,
        fileId: fileId,
        uri: uri,
        name: name,
        url: url ?? this.url,
        totalSize: totalSize,
        downloadedBytes: downloadedBytes ?? this.downloadedBytes,
        speed: speed ?? this.speed,
        status: status ?? this.status,
        threadCount: threadCount ?? this.threadCount,
        createdAt: createdAt,
        savePath: savePath,
        error: clearError ? null : (error ?? this.error),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'file_id': fileId,
        'uri': uri,
        'name': name,
        'url': url,
        'total_size': totalSize,
        'downloaded_bytes': downloadedBytes,
        'status': status.name,
        'thread_count': threadCount,
        'created_at': createdAt.toIso8601String(),
        'save_path': savePath,
        'error': error,
      };

  factory DownloadTask.fromJson(Map<String, dynamic> json) => DownloadTask(
        id: json['id'] as String? ?? '',
        fileId: json['file_id'] as String? ?? '',
        uri: json['uri'] as String? ?? '',
        name: json['name'] as String? ?? '',
        url: json['url'] as String? ?? '',
        totalSize: (json['total_size'] as num?)?.toInt() ?? 0,
        downloadedBytes: (json['downloaded_bytes'] as num?)?.toInt() ?? 0,
        speed: 0,
        status: downloadStatusFromString(json['status'] as String? ?? ''),
        threadCount: (json['thread_count'] as num?)?.toInt() ?? 1,
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ??
                DateTime.now(),
        savePath: json['save_path'] as String? ?? '',
        error: json['error'] as String?,
      );
}
