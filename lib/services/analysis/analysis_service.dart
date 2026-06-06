import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../pose/pose_classifier.dart';

export '../pose/pose_classifier.dart' show PoseLabel, FramePoseResult;

class AnalysisService {
  Map<String, dynamic>? _referencePoses;
  PoseClassifier? _classifier;

  Future<void> loadReferencePoses() async {
    final String response =
        await rootBundle.loadString('assets/data/reference_poses.json');
    _referencePoses = json.decode(response)['reference_poses']
        as Map<String, dynamic>;
    _classifier = PoseClassifier(referencePoses: _referencePoses!);
  }

  bool get isLoaded => _referencePoses != null;

  // -------------------------------------------------------------------------
  // Klasifikasi pose pada frame ini
  // -------------------------------------------------------------------------

  /// Klasifikasikan [pose] ke bersedia / berlari / unknown.
  FramePoseResult classifyPose(Pose pose) {
    if (_classifier == null) {
      return const FramePoseResult(label: PoseLabel.unknown, score: 0);
    }
    return _classifier!.classify(pose);
  }

  // -------------------------------------------------------------------------
  // Hitung skor satu frame terhadap referensi tertentu
  // -------------------------------------------------------------------------

  /// Skor kemiripan (0–100) antara [detectedPose] dan referensi [referenceType]
  /// ('bersedia' atau 'berlari').
  double calculatePoseScore(Pose detectedPose, String referenceType) {
    if (_classifier == null) return 0.0;
    return _classifier!.scoreAgainstReference(detectedPose, referenceType);
  }

  // -------------------------------------------------------------------------
  // Helper landmark map (untuk penggunaan lain bila perlu)
  // -------------------------------------------------------------------------

  PoseLandmarkType mapStringToLandmark(String name) {
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
