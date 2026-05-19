import 'dart:io';
import 'package:path_provider/path_provider.dart';

enum LogType { inference, evaluation, app }

class LoggerService {
  // Singleton pattern
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  Future<Directory> _getLogDir() async {
    final docDir = await getApplicationDocumentsDirectory();
    final logDir = Directory('${docDir.path}/logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    return logDir;
  }

  File _getFile(LogType type, Directory dir) {
    switch (type) {
      case LogType.inference:
        return File('${dir.path}/INFERENCE.log');
      case LogType.evaluation:
        return File('${dir.path}/EVALUATION.log');
      case LogType.app:
      default:
        return File('${dir.path}/APP.log');
    }
  }

  Future<void> log(String message, {LogType type = LogType.app, bool isError = false}) async {
    try {
      final dir = await _getLogDir();
      final file = _getFile(type, dir);
      final timestamp = DateTime.now().toIso8601String();
      final prefix = isError ? '[ERROR]' : '[INFO]';
      
      await file.writeAsString(
        '$timestamp $prefix: $message\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      // Fallback to debugPrint if file writing fails
      print('LoggerService Error: $e');
    }
  }
}
