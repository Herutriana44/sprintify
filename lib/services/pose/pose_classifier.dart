import 'dart:math';
import 'dart:typed_data';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Pose classification result: label + confidence score.
enum PoseLabel { bersedia, berlari, unknown }

class FramePoseResult {
  const FramePoseResult({
    required this.label,
    required this.score,
  });

  final PoseLabel label;
  final double score;
}

/// TFLite-based pose classifier for "bersedia" (ready) vs "berlari" (running).
///
/// Loads the trained TFLite model and runs inference on pose landmarks.
/// Falls back to unknown if model not available (during initial setup).
class PoseClassifier {
  Interpreter? _interpreter;
  bool _isInitialized = false;
  static const String _modelPath = 'assets/models/pose_classifier.tflite';
  static const int _inputSize = 151; // 99 coords + 39 bone vectors + 13 bone lengths

  /// Bone connections (same as training script)
  static const List<List<int>> _boneConnections = [
    [11, 13], [13, 15], // left arm
    [12, 14], [14, 16], // right arm
    [11, 12],            // shoulders
    [11, 23], [12, 24],  // torso sides
    [23, 25], [25, 27],  // left leg
    [24, 26], [26, 28],  // right leg
    [23, 24],            // hips
  ];

  /// Initialize TFLite model (called once at startup)
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      _interpreter = await Interpreter.fromAsset(_modelPath);
      _isInitialized = true;
    } catch (e) {
      // Model not available yet (training in progress) — continue with unknown labels
      print('PoseClassifier: TFLite model not found, falling back to unknown: $e');
    }
  }

  /// Classify pose from MLKit Pose landmarks
  FramePoseResult classify(Pose pose) {
    if (!_isInitialized || _interpreter == null) {
      return const FramePoseResult(label: PoseLabel.unknown, score: 0.0);
    }

    try {
      final features = _extractFeatures(pose);
      final predictions = _runInference(features);

      // Find top prediction
      double bestScore = 0.0;
      PoseLabel bestLabel = PoseLabel.unknown;

      if (predictions['bersedia'] != null && predictions['bersedia']! > bestScore) {
        bestScore = predictions['bersedia']!;
        bestLabel = PoseLabel.bersedia;
      }

      if (predictions['berlari'] != null && predictions['berlari']! > bestScore) {
        bestScore = predictions['berlari']!;
        bestLabel = PoseLabel.berlari;
      }

      return FramePoseResult(label: bestLabel, score: bestScore);
    } catch (e) {
      print('PoseClassifier error: $e');
      return const FramePoseResult(label: PoseLabel.unknown, score: 0.0);
    }
  }

  /// Classify from serialized landmarks (for isolate)
  FramePoseResult classifyFromMap(Map<String, Map<String, double>> landmarks) {
    if (!_isInitialized || _interpreter == null) {
      return const FramePoseResult(label: PoseLabel.unknown, score: 0.0);
    }

    try {
      final features = _extractFeaturesFromMap(landmarks);
      final predictions = _runInference(features);

      double bestScore = 0.0;
      PoseLabel bestLabel = PoseLabel.unknown;

      if (predictions['bersedia'] != null && predictions['bersedia']! > bestScore) {
        bestScore = predictions['bersedia']!;
        bestLabel = PoseLabel.bersedia;
      }

      if (predictions['berlari'] != null && predictions['berlari']! > bestScore) {
        bestScore = predictions['berlari']!;
        bestLabel = PoseLabel.berlari;
      }

      return FramePoseResult(label: bestLabel, score: bestScore);
    } catch (e) {
      print('PoseClassifier error: $e');
      return const FramePoseResult(label: PoseLabel.unknown, score: 0.0);
    }
  }

  /// Extract and normalize features from MLKit Pose
  List<double> _extractFeatures(Pose pose) {
    final landmarks = pose.landmarks;
    final coords = List.generate(33, (i) {
      final keys = [
        PoseLandmarkType.nose,
        PoseLandmarkType.leftEyeInner,
        PoseLandmarkType.leftEye,
        PoseLandmarkType.leftEyeOuter,
        PoseLandmarkType.rightEyeInner,
        PoseLandmarkType.rightEye,
        PoseLandmarkType.rightEyeOuter,
        PoseLandmarkType.leftEar,
        PoseLandmarkType.rightEar,
        PoseLandmarkType.leftMouth,
        PoseLandmarkType.rightMouth,
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.rightShoulder,
        PoseLandmarkType.leftElbow,
        PoseLandmarkType.rightElbow,
        PoseLandmarkType.leftWrist,
        PoseLandmarkType.rightWrist,
        PoseLandmarkType.leftPinky,
        PoseLandmarkType.rightPinky,
        PoseLandmarkType.leftIndex,
        PoseLandmarkType.rightIndex,
        PoseLandmarkType.leftThumb,
        PoseLandmarkType.rightThumb,
        PoseLandmarkType.leftHip,
        PoseLandmarkType.rightHip,
        PoseLandmarkType.leftKnee,
        PoseLandmarkType.rightKnee,
        PoseLandmarkType.leftAnkle,
        PoseLandmarkType.rightAnkle,
        PoseLandmarkType.leftHeel,
        PoseLandmarkType.rightHeel,
        PoseLandmarkType.leftFootIndex,
        PoseLandmarkType.rightFootIndex,
      ][i];
      final lm = landmarks[keys];
      return [lm?.x ?? 0.0, lm?.y ?? 0.0, lm?.z ?? 0.0];
    });

    return _normalizeAndBuild(coords);
  }

  /// Extract features from serialized landmarks
  List<double> _extractFeaturesFromMap(Map<String, Map<String, double>> landmarks) {
    final coordMap = {
      'left_shoulder': [landmarks['left_shoulder']?['x'] ?? 0, landmarks['left_shoulder']?['y'] ?? 0, landmarks['left_shoulder']?['z'] ?? 0],
      'right_shoulder': [landmarks['right_shoulder']?['x'] ?? 0, landmarks['right_shoulder']?['y'] ?? 0, landmarks['right_shoulder']?['z'] ?? 0],
      'left_hip': [landmarks['left_hip']?['x'] ?? 0, landmarks['left_hip']?['y'] ?? 0, landmarks['left_hip']?['z'] ?? 0],
      'right_hip': [landmarks['right_hip']?['x'] ?? 0, landmarks['right_hip']?['y'] ?? 0, landmarks['right_hip']?['z'] ?? 0],
    };

    final coords = List.generate(33, (i) => [0.0, 0.0, 0.0]);
    coords[11] = (coordMap['left_shoulder'] as List).cast<double>();
    coords[12] = (coordMap['right_shoulder'] as List).cast<double>();
    coords[23] = (coordMap['left_hip'] as List).cast<double>();
    coords[24] = (coordMap['right_hip'] as List).cast<double>();

    return _normalizeAndBuild(coords);
  }

  /// Normalize coordinates and build feature vector
  List<double> _normalizeAndBuild(List<List<double>> coords) {
    final leftHip = coords[23];
    final rightHip = coords[24];
    final hipCenter = [
      (leftHip[0] + rightHip[0]) / 2,
      (leftHip[1] + rightHip[1]) / 2,
      (leftHip[2] + rightHip[2]) / 2,
    ];

    final normalized = coords.map((c) => [
      c[0] - hipCenter[0],
      c[1] - hipCenter[1],
      c[2] - hipCenter[2],
    ]).toList();

    final leftShoulder = normalized[11];
    final torsoLen = (leftShoulder[0] * leftShoulder[0] +
            leftShoulder[1] * leftShoulder[1] +
            leftShoulder[2] * leftShoulder[2])
        .toDouble();

    if (torsoLen > 1e-6) {
      final scale = 1.0 / sqrt(torsoLen);
      for (int i = 0; i < normalized.length; i++) {
        normalized[i] = [
          normalized[i][0] * scale,
          normalized[i][1] * scale,
          normalized[i][2] * scale,
        ];
      }
    }

    final features = <double>[];
    for (final c in normalized) {
      features.addAll(c);
    }

    for (final conn in _boneConnections) {
      final start = normalized[conn[0]];
      final end = normalized[conn[1]];
      features.add(end[0] - start[0]);
      features.add(end[1] - start[1]);
      features.add(end[2] - start[2]);
    }

    for (final conn in _boneConnections) {
      final start = normalized[conn[0]];
      final end = normalized[conn[1]];
      final dx = end[0] - start[0];
      final dy = end[1] - start[1];
      final dz = end[2] - start[2];
      features.add(dx * dx + dy * dy + dz * dz);
    }

    return features;
  }

  /// Run TFLite inference
  Map<String, double> _runInference(List<double> features) {
    if (features.length != _inputSize) {
      print('Warning: expected $_inputSize features, got ${features.length}');
      // Pad or truncate
      final padded = List<double>.filled(_inputSize, 0.0);
      for (int i = 0; i < features.length && i < _inputSize; i++) {
        padded[i] = features[i];
      }
      features = padded;
    }

    final input = [features];
    final output = List<List<double>>.filled(1, List.filled(2, 0.0));
    _interpreter!.run(input, output);

    return {
      'bersedia': output[0][0],
      'berlari': output[0][1],
    };
  }

  void dispose() {
    _interpreter?.close();
  }

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
