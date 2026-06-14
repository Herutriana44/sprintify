import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Hasil klasifikasi satu frame pose.
enum PoseLabel { bersedia, berlari, unknown }

class FramePoseResult {
  const FramePoseResult({
    required this.label,
    required this.score,
  });

  final PoseLabel label;
  final double score;
}

/// Klasifikasi pose berdasarkan data referensi JSON.
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

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Klasifikasi [pose] ML Kit — dipakai di main isolate.
  FramePoseResult classify(Pose pose) {
    return classifyFromMap(_landmarksToMap(pose));
  }

  /// Klasifikasi dari Map plain-Dart — dipakai di dalam classifier isolate.
  FramePoseResult classifyFromMap(Map<String, Map<String, double>> landmarks) {
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

  /// Skor kemiripan (0–100) antara [pose] dan referensi [referenceKey].
  double scoreAgainstReference(Pose pose, String referenceKey) {
    final ref = _refs[referenceKey];
    if (ref == null) return 0.0;
    final landmarksRef = ref['landmarks'] as Map<String, dynamic>?;
    if (landmarksRef == null) return 0.0;
    return _computeScoreFromMap(_landmarksToMap(pose), landmarksRef);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Konversi Pose ML Kit → Map plain-Dart dengan key string sesuai JSON.
  static Map<String, Map<String, double>> _landmarksToMap(Pose pose) {
    final result = <String, Map<String, double>>{};
    for (final entry in pose.landmarks.entries) {
      final key = landmarkTypeToString(entry.key);
      if (key != null) {
        result[key] = {'x': entry.value.x, 'y': entry.value.y};
      }
    }
    return result;
  }

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
    return ((1.0 - avgSqDist.clamp(0.0, 1.0)) * 100).clamp(0.0, 100.0);
  }

  PoseLabel _labelFromString(String key) {
    switch (key) {
      case 'bersedia': return PoseLabel.bersedia;
      case 'berlari':  return PoseLabel.berlari;
      default:         return PoseLabel.unknown;
    }
  }

  // ---------------------------------------------------------------------------
  // Static mapping PoseLandmarkType → JSON key string
  // (public agar bisa dipakai di classifier_isolate.dart)
  // ---------------------------------------------------------------------------

  static String? landmarkTypeToString(PoseLandmarkType type) {
    switch (type) {
      case PoseLandmarkType.nose:           return 'nose';
      case PoseLandmarkType.leftShoulder:   return 'left_shoulder';
      case PoseLandmarkType.rightShoulder:  return 'right_shoulder';
      case PoseLandmarkType.leftElbow:      return 'left_elbow';
      case PoseLandmarkType.rightElbow:     return 'right_elbow';
      case PoseLandmarkType.leftWrist:      return 'left_wrist';
      case PoseLandmarkType.rightWrist:     return 'right_wrist';
      case PoseLandmarkType.leftHip:        return 'left_hip';
      case PoseLandmarkType.rightHip:       return 'right_hip';
      case PoseLandmarkType.leftKnee:       return 'left_knee';
      case PoseLandmarkType.rightKnee:      return 'right_knee';
      case PoseLandmarkType.leftAnkle:      return 'left_ankle';
      case PoseLandmarkType.rightAnkle:     return 'right_ankle';
      case PoseLandmarkType.leftEar:        return 'left_ear';
      case PoseLandmarkType.rightEar:       return 'right_ear';
      case PoseLandmarkType.leftEye:        return 'left_eye';
      case PoseLandmarkType.rightEye:       return 'right_eye';
      case PoseLandmarkType.leftPinky:      return 'left_pinky';
      case PoseLandmarkType.rightPinky:     return 'right_pinky';
      case PoseLandmarkType.leftIndex:      return 'left_index';
      case PoseLandmarkType.rightIndex:     return 'right_index';
      case PoseLandmarkType.leftThumb:      return 'left_thumb';
      case PoseLandmarkType.rightThumb:     return 'right_thumb';
      case PoseLandmarkType.leftHeel:       return 'left_heel';
      case PoseLandmarkType.rightHeel:      return 'right_heel';
      case PoseLandmarkType.leftFootIndex:  return 'left_foot_index';
      case PoseLandmarkType.rightFootIndex: return 'right_foot_index';
      default:                              return null;
    }
  }
}
