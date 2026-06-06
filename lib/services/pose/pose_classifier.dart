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

  /// Klasifikasi [pose] ke dalam salah satu [PoseLabel].
  FramePoseResult classify(Pose pose) {
    double bestScore = -1;
    PoseLabel bestLabel = PoseLabel.unknown;

    for (final entry in _refs.entries) {
      final label = _labelFromString(entry.key);
      if (label == PoseLabel.unknown) continue;

      final landmarksRef = entry.value['landmarks'] as Map<String, dynamic>?;
      if (landmarksRef == null) continue;

      final score = _computeScore(pose, landmarksRef);
      final threshold = (entry.value['thresholds']?['min_score_to_classify']
              as num?)
          ?.toDouble() ?? _defaultThreshold;

      if (score > bestScore) {
        bestScore = score;
        // Only set label if above threshold
        bestLabel = score >= threshold ? label : PoseLabel.unknown;
      }
    }

    // If no label passed threshold but we have a best score, keep unknown
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
    return _computeScore(pose, landmarksRef);
  }

  double _computeScore(Pose pose, Map<String, dynamic> landmarksRef) {
    double totalSqDist = 0.0;
    int count = 0;

    for (final entry in landmarksRef.entries) {
      final landmarkType = _mapStringToLandmark(entry.key);
      final detected = pose.landmarks[landmarkType];
      if (detected == null) continue;

      final refX = (entry.value['x'] as num).toDouble();
      final refY = (entry.value['y'] as num).toDouble();

      // Normalised coordinates are in 0-1 space for both detected & reference
      final dx = detected.x - refX;
      final dy = detected.y - refY;
      totalSqDist += dx * dx + dy * dy;
      count++;
    }

    if (count == 0) return 0.0;

    // Average squared distance; max theoretical is ~2 (diagonal of unit square)
    final avgSqDist = totalSqDist / count;
    // Map to 0–100 (clamp so it never goes negative)
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

  PoseLandmarkType _mapStringToLandmark(String name) {
    switch (name) {
      case 'nose':
        return PoseLandmarkType.nose;
      case 'left_shoulder':
        return PoseLandmarkType.leftShoulder;
      case 'right_shoulder':
        return PoseLandmarkType.rightShoulder;
      case 'left_elbow':
        return PoseLandmarkType.leftElbow;
      case 'right_elbow':
        return PoseLandmarkType.rightElbow;
      case 'left_wrist':
        return PoseLandmarkType.leftWrist;
      case 'right_wrist':
        return PoseLandmarkType.rightWrist;
      case 'left_hip':
        return PoseLandmarkType.leftHip;
      case 'right_hip':
        return PoseLandmarkType.rightHip;
      case 'left_knee':
        return PoseLandmarkType.leftKnee;
      case 'right_knee':
        return PoseLandmarkType.rightKnee;
      case 'left_ankle':
        return PoseLandmarkType.leftAnkle;
      case 'right_ankle':
        return PoseLandmarkType.rightAnkle;
      default:
        return PoseLandmarkType.nose;
    }
  }
}
