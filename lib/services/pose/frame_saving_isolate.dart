import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

// ---------------------------------------------------------------------------
// Message types
// ---------------------------------------------------------------------------

class _SaveFrameTask {
  const _SaveFrameTask({
    required this.taskId,
    required this.frameBytes,
    required this.label,
    required this.timestamp,
    required this.outputDir,
  });

  final int taskId;
  final Uint8List frameBytes;
  final String label;
  final int timestamp;
  final String outputDir;
}

// ---------------------------------------------------------------------------
// Isolate entry point
// ---------------------------------------------------------------------------

void _frameSavingIsolateEntry(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  receivePort.listen((dynamic message) async {
    if (message is _SaveFrameTask) {
      try {
        final path = '${message.outputDir}/best_${message.label}_${message.timestamp}.jpg';
        final file = File(path);

        // Ensure directory exists
        final dir = Directory(message.outputDir);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }

        await file.writeAsBytes(message.frameBytes);

        mainSendPort.send(_SaveFrameResult(
          taskId: message.taskId,
          result: const FrameSavingResult(success: true, path: path),
        ));
      } catch (e) {
        mainSendPort.send(_SaveFrameResult(
          taskId: message.taskId,
          result: FrameSavingResult(success: false, path: null, error: e.toString()),
        ));
      }
    }
  });
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

class FrameSavingResult {
  const FrameSavingResult({
    required this.success,
    required this.path,
    this.error,
  });

  final bool success;
  final String? path;
  final String? error;
}

class FrameSavingIsolate {
  Isolate? _isolate;
  SendPort? _sendPort;
  final ReceivePort _receivePort = ReceivePort();
  final Map<int, Completer<FrameSavingResult>> _pending = {};
  int _nextTaskId = 0;

  Future<void> start() async {
    _isolate = await Isolate.spawn(_frameSavingIsolateEntry, _receivePort.sendPort);

    final completer = Completer<void>();
    _receivePort.listen((dynamic message) {
      if (message is SendPort) {
        _sendPort = message;
        completer.complete();
      } else if (message is _SaveFrameResult) {
        _pending.remove(message.taskId)?.complete(message.result);
      }
    });

    return completer.future;
  }

  Future<FrameSavingResult> saveFrame({
    required Uint8List frameBytes,
    required String label,
    required int timestamp,
    required String outputDir,
  }) {
    final taskId = _nextTaskId++;
    final completer = Completer<FrameSavingResult>();
    _pending[taskId] = completer;

    _sendPort!.send(_SaveFrameTask(
      taskId: taskId,
      frameBytes: frameBytes,
      label: label,
      timestamp: timestamp,
      outputDir: outputDir,
    ));

    return completer.future;
  }

  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _receivePort.close();
    for (final c in _pending.values) {
      if (!c.isCompleted) {
        c.complete(const FrameSavingResult(success: false, path: null, error: 'Isolate disposed'));
      }
    }
    _pending.clear();
  }
}

class _SaveFrameResult {
  const _SaveFrameResult({
    required this.taskId,
    required this.result,
  });

  final int taskId;
  final FrameSavingResult result;
}
