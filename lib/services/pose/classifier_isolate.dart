import 'dart:async';
import 'dart:isolate';

import 'pose_classifier.dart';

// ---------------------------------------------------------------------------
// Pesan yang dikirim KE isolate
// ---------------------------------------------------------------------------

class _ClassifyRequest {
  const _ClassifyRequest({
    required this.id,
    required this.landmarks,
    required this.referencePoses,
  });

  /// ID unik request — dipakai untuk mencocokkan response.
  final int id;

  /// Landmark pose yang sudah diubah ke Map plain-Dart agar bisa di-transfer.
  final Map<String, Map<String, double>> landmarks;

  /// Data referensi pose (dari JSON asset).
  /// Hanya dikirim satu kali saat inisialisasi (id == -1).
  final Map<String, dynamic>? referencePoses;
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

  receivePort.listen((dynamic message) {
    if (message is! _ClassifyRequest) return;

    // Inisialisasi / update classifier bila referencePoses dikirim
    if (message.referencePoses != null) {
      classifier = PoseClassifier(referencePoses: message.referencePoses!);
      // Pesan init (id == -1) tidak memerlukan response
      if (message.id == -1) return;
    }

    if (classifier == null) {
      mainSendPort.send(ClassifyResult(
        id: message.id,
        label: PoseLabel.unknown,
        score: 0,
      ));
      return;
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
///   Main isolate                     Classifier isolate
///   ─────────────────────────────    ─────────────────────────
///   ML Kit deteksi pose          →   (tidak dipakai)
///   serialize landmarks          →   classifyFromMap()
///   await Future result          ←   kirim ClassifyResult
///   update UI
class ClassifierIsolate {
  Isolate? _isolate;
  SendPort? _sendPort;
  final ReceivePort _receivePort = ReceivePort();
  final Map<int, Completer<ClassifyResult>> _pending = {};
  int _nextId = 0;
  bool _ready = false;

  /// Start isolate dan kirim data referensi pose.
  /// Harus dipanggil sebelum [classify].
  Future<void> start(Map<String, dynamic> referencePoses) async {
    _isolate = await Isolate.spawn(_isolateEntry, _receivePort.sendPort);

    final readyCompleter = Completer<void>();

    _receivePort.listen((dynamic message) {
      if (message is SendPort) {
        _sendPort = message;
        // Kirim referensi pose ke isolate (init request, id = -1)
        _sendPort!.send(_ClassifyRequest(
          id: -1,
          landmarks: const {},
          referencePoses: referencePoses,
        ));
        _ready = true;
        readyCompleter.complete();
      } else if (message is ClassifyResult) {
        _pending.remove(message.id)?.complete(message);
      }
    });

    return readyCompleter.future;
  }

  /// Kirim [pose] ke isolate untuk diklasifikasi.
  /// Mengembalikan [Future] yang akan selesai saat isolate mengirim hasilnya.
  Future<ClassifyResult> classify(
      Map<String, Map<String, double>> serializedLandmarks) {
    assert(_ready, 'ClassifierIsolate.start() belum dipanggil');
    final id = _nextId++;
    final completer = Completer<ClassifyResult>();
    _pending[id] = completer;

    _sendPort!.send(_ClassifyRequest(
      id: id,
      landmarks: serializedLandmarks,
      referencePoses: null,
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
// (top-level agar bisa dipakai dari mana saja tanpa import google_mlkit)
// ---------------------------------------------------------------------------

/// Ubah landmark [PoseLandmarkType → PoseLandmark] ke Map plain-Dart
/// yang bisa dikirim via SendPort ke isolate lain.
Map<String, Map<String, double>> serializePoseLandmarks(
    Map<dynamic, dynamic> landmarks) {
  final result = <String, Map<String, double>>{};
  for (final entry in landmarks.entries) {
    // entry.key adalah PoseLandmarkType, .name menghasilkan string enum
    result[entry.key.name as String] = {
      'x': (entry.value.x as double),
      'y': (entry.value.y as double),
    };
  }
  return result;
}
