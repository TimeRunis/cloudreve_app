import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import '../i18n/app_localizations.dart';

/// 应用日志，基于三方包 `logger`：控制台 + 文件双输出。
///
/// 用法：
/// ```dart
/// AppLogger.log.i('[UploadManager] 开始上传');
/// AppLogger.log.e('[UploadManager] 上传失败', error: e, stackTrace: st);
/// ```
///
/// [init] 在 runApp 之前调用；未初始化时退化为仅控制台输出。
class AppLogger {
  AppLogger._();

  /// 日志文件名，固定写在应用文档目录下。
  static const String fileName = 'cloudreve_app.log';

  /// 输出格式：关掉颜色（避免 ANSI 转义写进文件）、关掉 emoji 和边框。
  static final LogPrinter _printer = PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 8,
    lineLength: 100,
    colors: false,
    printEmojis: false,
    noBoxingByDefault: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  );

  static final Logger _consoleOnly = Logger(
    filter: ProductionFilter(),
    printer: _printer,
    output: ConsoleOutput(),
  );

  static Logger? _instance;
  static File? _logFile;

  /// 全局 Logger 实例。
  static Logger get log => _instance ?? _consoleOnly;

  /// 当前日志文件；[init] 之前为 null。
  static File? get logFile => _logFile;

  /// 初始化文件输出，重复调用会直接返回。
  static Future<void> init() async {
    if (_instance != null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}$fileName');
      await file.parent.create(recursive: true);
      _logFile = file;
      _instance = Logger(
        filter: ProductionFilter(),
        printer: _printer,
        output: MultiOutput([
          ConsoleOutput(),
          FileOutput(file: file),
        ]),
      );
      log.i('[AppLogger] 日志文件：${file.path}');
    } catch (e, stackTrace) {
      // 文件不可写时退化为仅控制台，不影响应用启动。
      _consoleOnly.e(
        tr('[AppLogger] 初始化文件日志失败，仅输出到控制台'),
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// 把当前日志文件复制成带时间戳的导出文件并返回。
  ///
  /// 复制而不是直接给出原文件，是为了拿到一份不再追加的快照。
  static Future<File> export() async {
    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp = '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
    final target = File(
      '${dir.path}${Platform.pathSeparator}cloudreve_log_$stamp.log',
    );
    final source = _logFile;
    if (source != null && await source.exists()) {
      return source.copy(target.path);
    }
    await target.writeAsString(tr('（暂无日志）\n'), flush: true);
    return target;
  }
}
