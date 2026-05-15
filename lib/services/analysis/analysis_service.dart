import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class AnalysisService {
  Map<String, dynamic>? _referencePoses;

  Future<void> loadReferencePoses() async {
    final String response = await rootBundle.loadString('assets/data/reference_poses.json');
    _referencePoses = json.decode(response)['reference_poses'];
  }

  // Menghitung skor kemiripan antara pose terdeteksi dan referensi
  double calculatePoseScore(Pose detectedPose, String referenceType) {
    if (_referencePoses == null || !_referencePoses!.containsKey(referenceType)) {
      return 0.0;
    }

    final ref = _referencePoses![referenceType]['landmarks'];
    double totalDistance = 0.0;
    int count = 0;

    for (var entry in ref.entries) {
      final landmarkType = _mapStringToLandmark(entry.key);
      if (detectedPose.landmarks.containsKey(landmarkType)) {
        final landmark = detectedPose.landmarks[landmarkType]!;
        final refX = entry.value['x'];
        final refY = entry.value['y'];
        
        // Jarak Euclidean sederhana (normalisasi landmark pose biasanya 0-1)
        final dx = landmark.x - refX;
        final dy = landmark.y - refY;
        totalDistance += (dx * dx + dy * dy);
        count++;
      }
    }

    if (count == 0) return 0.0;
    
    // Skor 0-100 (semakin kecil jarak semakin tinggi skor)
    double averageDistance = totalDistance / count;
    return (1.0 - (averageDistance > 1.0 ? 1.0 : averageDistance)) * 100;
  }

  PoseLandmarkType _mapStringToLandmark(String name) {
    switch (name) {
      case 'left_shoulder': return PoseLandmarkType.leftShoulder;
      case 'right_shoulder': return PoseLandmarkType.rightShoulder;
      case 'left_hip': return PoseLandmarkType.leftHip;
      case 'right_hip': return PoseLandmarkType.rightHip;
      case 'left_knee': return PoseLandmarkType.leftKnee;
      case 'right_knee': return PoseLandmarkType.rightKnee;
      case 'left_ankle': return PoseLandmarkType.leftAnkle;
      case 'right_ankle': return PoseLandmarkType.rightAnkle;
      default: return PoseLandmarkType.nose;
    }
  }
}
