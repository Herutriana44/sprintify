import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../pose/pose_classifier.dart';
import '../pose/classifier_isolate.dart';

export '../pose/pose_classifier.dart' show PoseLabel, FramePoseResult;

class AnalysisService {
  Map<String, dynamic>? _referencePoses;

  // Long-lived isolate — classifier berjalan di thread terpisah
  final ClassifierIsolate _classifierIsolate = ClassifierIsolate();

  /// Muat referensi pose dari asset lalu start isolate classifier.
  Future<void> loadReferencePoses() async {
    final String response =
        await rootBundle.loadString('assets/data/reference_poses.json');
    _referencePoses =
        json.decode(response)['reference_poses'] as Map<String, dynamic>;

    await _classifierIsolate.start();
  }

  bool get isLoaded =>
      _referencePoses != null && _classifierIsolate.isReady;

  // ---------------------------------------------------------------------------
  // Klasifikasi pose — dijalankan di isolate terpisah (non-blocking)
  // ---------------------------------------------------------------------------

  /// Serialisasi landmark [pose] lalu kirim ke classifier isolate.
  /// Mengembalikan [Future] — tidak memblokir main/UI thread.
  Future<FramePoseResult> classifyPoseAsync(Pose pose) async {
    if (!_classifierIsolate.isReady) {
      return const FramePoseResult(label: PoseLabel.unknown, score: 0);
    }

    // Serialisasi di main isolate (cepat, hanya copy koordinat double)
    final serialized = serializePoseLandmarks(pose.landmarks);

    final result = await _classifierIsolate.classify(serialized);
    return FramePoseResult(label: result.label, score: result.score);
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  void dispose() {
    _classifierIsolate.dispose();
  }
}
