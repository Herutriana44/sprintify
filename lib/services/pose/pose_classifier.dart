import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Hasil klasifikasi satu frame pose.
enum PoseLabel { bersedia, berlari, unknown }

class FramePoseResult {
  const FramePoseResult({
    required this.label,
    required this.score,
  });

  /// Label posisi yang terdeteksi pada frame ini.
  final PoseLabel label;

  /// Skor kemiripan (0–100) terhadap referensi label yang terpilih.
  final double score;
}

/// Modul klasifikasi pose berdasarkan data referensi JSON.
///
/// Cara kerja:
/// 1. Hitung skor Euclidean terhadap semua landmark referensi untuk
///    setiap kategori (bersedia / berlari).
/// 2. Pilih kategori dengan skor tertinggi.
/// 3. Jika skor tertinggi < threshold, kembalikan [PoseLabel.unknown].
class PoseClassifier {
  PoseClassifier({required Map<String, dynamic> referencePoses})
      : _refs = referencePoses;

  final Map<String, dynamic> _refs;

  static const double _defaultThreshold = 45.0;

  /// Klasifikasi [pose] ML Kit ke dalam salah satu [PoseLabel].
  /// Dipakai di main isolate.
  FramePoseResult classify(Pose pose) {
    // Serialisasi ke Map plain-Dart lalu delegasikan ke classifyFromMap
    final map = <String, Map<String, double>>{};
    for (final entry in pose.landmarks.entries) {
      map[entry.key.name] = {
        'x': entry.value.x,
        'y': entry.value.y,
      };
    }
    return classifyFromMap(map);
  }

  /// Klasifikasi dari Map plain-Dart landmark.
  /// Bisa dipakai di dalam isolate (tidak bergantung pada ML Kit object).
  FramePoseResult classifyFromMap(
      Map<String, Map<String, double>> landmarks) {
    double bestScore = -1;
    PoseLabel bestLabel = PoseLabel.unknown;

    for (final entry in _refs.entries) {
      final label = _labelFromString(entry.key);
      if (label == PoseLabel.unknown) continue;

      final landmarksRef = entry.value['landmarks'] as Map<String, dynamic>?;
      if (landmarksRef == null) continue;

      final score = _computeScoreFromMap(landmarks, landmarksRef);
      final threshold =
          (entry.value['thresholds']?['min_score_to_classify'] as num?)
                  ?.toDouble() ??
              _defaultThreshold;

      if (score > bestScore) {
        bestScore = score;
        bestLabel = score >= threshold ? label : PoseLabel.unknown;
      }
    }

    return FramePoseResult(
      label: bestLabel,
      score: bestScore < 0 ? 0 : bestScore,
    );
  }

  /// Hitung skor (0–100) kemiripan pose dengan data referensi landmark.
  double scoreAgainstReference(Pose pose, String referenceKey) {
    final ref = _refs[referenceKey];
    if (ref == null) return 0.0;
    final landmarksRef = ref['landmarks'] as Map<String, dynamic>?;
    if (landmarksRef == null) return 0.0;

    final map = <String, Map<String, double>>{};
    for (final entry in pose.landmarks.entries) {
      map[entry.key.name] = {
        'x': entry.value.x,
        'y': entry.value.y,
      };
    }
    return _computeScoreFromMap(map, landmarksRef);
  }

  /// Skor dari Map plain-Dart (dipakai di isolate).
  double _computeScoreFromMap(
    Map<String, Map<String, double>> detected,
    Map<String, dynamic> landmarksRef,
  ) {
    double totalSqDist = 0.0;
    int count = 0;

    for (final entry in landmarksRef.entries) {
      final lm = detected[entry.key];
      if (lm == null) continue;

      final refX = (entry.value['x'] as num).toDouble();
      final refY = (entry.value['y'] as num).toDouble();
      final dx = lm['x']! - refX;
      final dy = lm['y']! - refY;
      totalSqDist += dx * dx + dy * dy;
      count++;
    }

    if (count == 0) return 0.0;

    final avgSqDist = totalSqDist / count;
    return ((1.0 - (avgSqDist.clamp(0.0, 1.0))) * 100).clamp(0.0, 100.0);
  }

  PoseLabel _labelFromString(String key) {
    switch (key) {
      case 'bersedia':
        return PoseLabel.bersedia;
      case 'berlari':
        return PoseLabel.berlari;
      default:
        return PoseLabel.unknown;
    }
  }
}
