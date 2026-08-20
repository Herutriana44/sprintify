import 'dart:async';
import 'dart:isolate';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'pose_classifier.dart';

// ---------------------------------------------------------------------------
// Pesan yang dikirim KE isolate
// ---------------------------------------------------------------------------

class _ClassifyRequest {
  const _ClassifyRequest({
    required this.id,
    required this.landmarks,
  });

  /// ID unik request — dipakai untuk mencocokkan response.
  final int id;

  /// Landmark pose yang sudah diubah ke Map plain-Dart agar bisa di-transfer.
  final Map<String, Map<String, double>> landmarks;
}

// ---------------------------------------------------------------------------
// Pesan yang dikirim DARI isolate
// ---------------------------------------------------------------------------

class ClassifyResult {
  const ClassifyResult({
    required this.id,
    required this.label,
    required this.score,
  });
  final int id;
  final PoseLabel label;
  final double score;
}

// ---------------------------------------------------------------------------
// Entry-point isolate (wajib top-level untuk Isolate.spawn)
// ---------------------------------------------------------------------------

void _isolateEntry(SendPort mainSendPort) {
  final receivePort = ReceivePort();

  // Kirim balik SendPort kita agar main isolate bisa mengirim request
  mainSendPort.send(receivePort.sendPort);

  PoseClassifier? classifier;

  receivePort.listen((dynamic message) async {
    if (message is! _ClassifyRequest) return;

    // Init: buat classifier & load TFLite model (hanya sekali, id == -1)
    if (classifier == null) {
      classifier = PoseClassifier();
      await classifier!.initialize();
      if (message.id == -1) return;
    }

    final result = classifier!.classifyFromMap(message.landmarks);
    mainSendPort.send(ClassifyResult(
      id: message.id,
      label: result.label,
      score: result.score,
    ));
  });
}

// ---------------------------------------------------------------------------
// ClassifierIsolate — antarmuka publik
// ---------------------------------------------------------------------------

/// Long-lived isolate untuk menjalankan [PoseClassifier] di thread terpisah.
///
/// Pipeline:
///   Main isolate                       Classifier isolate
///   ───────────────────────────────    ────────────────────────
///   ML Kit deteksi pose landmarks  →   classifyFromMap()
///   serializePoseLandmarks()       →   classifyFromMap()
///   await Future<ClassifyResult>   ←   kirim ClassifyResult
///   update UI / accumulate scores
class ClassifierIsolate {
  Isolate? _isolate;
  SendPort? _sendPort;
  final ReceivePort _receivePort = ReceivePort();
  final Map<int, Completer<ClassifyResult>> _pending = {};
  int _nextId = 0;
  bool _ready = false;

  /// Start isolate dan load TFLite model di background.
  /// Harus dipanggil sebelum [classify].
  Future<void> start() async {
    _isolate = await Isolate.spawn(_isolateEntry, _receivePort.sendPort);

    final readyCompleter = Completer<void>();

    _receivePort.listen((dynamic message) {
      if (message is SendPort) {
        _sendPort = message;
        // Kirim init request (id = -1) agar isolate load TFLite model
        _sendPort!.send(const _ClassifyRequest(
          id: -1,
          landmarks: {},
        ));
        _ready = true;
        readyCompleter.complete();
      } else if (message is ClassifyResult) {
        _pending.remove(message.id)?.complete(message);
      }
    });

    return readyCompleter.future;
  }

  /// Kirim landmarks terserialisasi ke isolate untuk diklasifikasi.
  /// Gunakan [serializePoseLandmarks] untuk mengkonversi Pose ML Kit terlebih dahulu.
  Future<ClassifyResult> classify(
      Map<String, Map<String, double>> serializedLandmarks) {
    assert(_ready, 'ClassifierIsolate.start() belum dipanggil');
    final id = _nextId++;
    final completer = Completer<ClassifyResult>();
    _pending[id] = completer;

    _sendPort!.send(_ClassifyRequest(
      id: id,
      landmarks: serializedLandmarks,
    ));

    return completer.future;
  }

  bool get isReady => _ready;

  /// Hentikan isolate dan bersihkan semua resource.
  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _receivePort.close();
    _ready = false;
    for (final c in _pending.values) {
      if (!c.isCompleted) {
        c.complete(const ClassifyResult(
          id: -1,
          label: PoseLabel.unknown,
          score: 0,
        ));
      }
    }
    _pending.clear();
  }
}

// ---------------------------------------------------------------------------
// Helper: serialisasi Pose ML Kit → Map plain-Dart
// Dipakai di main isolate sebelum mengirim data ke classifier isolate.
// ---------------------------------------------------------------------------

/// Ubah landmarks Pose ML Kit ke Map plain-Dart yang bisa dikirim via SendPort.
/// Menggunakan [PoseClassifier.landmarkTypeToString] untuk mapping key.
Map<String, Map<String, double>> serializePoseLandmarks(
    Map<PoseLandmarkType, PoseLandmark> landmarks) {
  final result = <String, Map<String, double>>{};
  for (final entry in landmarks.entries) {
    final key = PoseClassifier.landmarkTypeToString(entry.key);
    if (key != null) {
      result[key] = {
        'x': entry.value.x,
        'y': entry.value.y,
      };
    }
  }
  return result;
}
