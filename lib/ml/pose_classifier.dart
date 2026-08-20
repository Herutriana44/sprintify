import 'dart:math';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// TFLite-based pose classifier for "bersedia" (ready) vs "berlari" (running).
/// Feature extraction matches train_pose_classifier.py exactly.
class PoseClassifier {
  late Interpreter _interpreter;
  late List<String> _labels;
  late int _inputSize;
  bool _isInitialized = false;

  /// Bone connections used in training (same as train_pose_classifier.py).
  /// Indices correspond to MediaPipe landmark order (0–32).
  static const List<List<int>> boneConnections = [
    [11, 13], [13, 15], // left arm
    [12, 14], [14, 16], // right arm
    [11, 12],           // shoulders
    [11, 23], [12, 24], // torso sides
    [23, 25], [25, 27], // left leg
    [24, 26], [26, 28], // right leg
    [23, 24],           // hips
  ];

  /// MediaPipe landmark order (indices 0–32).
  static const List<PoseLandmarkType> _landmarkOrder = [
    PoseLandmarkType.nose,            // 0
    PoseLandmarkType.leftEyeInner,    // 1
    PoseLandmarkType.leftEye,         // 2
    PoseLandmarkType.leftEyeOuter,    // 3
    PoseLandmarkType.rightEyeInner,   // 4
    PoseLandmarkType.rightEye,        // 5
    PoseLandmarkType.rightEyeOuter,   // 6
    PoseLandmarkType.leftEar,         // 7
    PoseLandmarkType.rightEar,        // 8
    PoseLandmarkType.leftMouth,       // 9
    PoseLandmarkType.rightMouth,      // 10
    PoseLandmarkType.leftShoulder,    // 11
    PoseLandmarkType.rightShoulder,   // 12
    PoseLandmarkType.leftElbow,       // 13
    PoseLandmarkType.rightElbow,      // 14
    PoseLandmarkType.leftWrist,       // 15
    PoseLandmarkType.rightWrist,      // 16
    PoseLandmarkType.leftPinky,       // 17
    PoseLandmarkType.rightPinky,      // 18
    PoseLandmarkType.leftIndex,       // 19
    PoseLandmarkType.rightIndex,      // 20
    PoseLandmarkType.leftThumb,       // 21
    PoseLandmarkType.rightThumb,      // 22
    PoseLandmarkType.leftHip,         // 23
    PoseLandmarkType.rightHip,        // 24
    PoseLandmarkType.leftKnee,        // 25
    PoseLandmarkType.rightKnee,       // 26
    PoseLandmarkType.leftAnkle,       // 27
    PoseLandmarkType.rightAnkle,      // 28
    PoseLandmarkType.leftHeel,        // 29
    PoseLandmarkType.rightHeel,       // 30
    PoseLandmarkType.leftFootIndex,   // 31
    PoseLandmarkType.rightFootIndex,  // 32
  ];

  /// Initialize the classifier with TFLite model and labels.
  Future<void> initialize({
    required String modelPath,
    required List<String> labels,
  }) async {
    if (_isInitialized) return;
    try {
      _interpreter = await Interpreter.fromAsset(modelPath);
      _labels = labels;
      _inputSize = _interpreter.getInputTensor(0).shape[1];
      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize PoseClassifier: $e');
    }
  }

  bool get isInitialized => _isInitialized;

  /// Extract normalized bone-vector features from MLKit Pose object.
  /// Returns flat feature vector matching training features.
  List<double> extractFeaturesFromPose(Pose pose) {
    final landmarks = pose.landmarks;

    // Extract raw x/y/z for each landmark in MediaPipe order
    final coords = List.generate(33, (i) {
      final lm = landmarks[_landmarkOrder[i]];
      return [lm?.x ?? 0.0, lm?.y ?? 0.0, lm?.z ?? 0.0];
    });

    // Translate so hip center is origin
    final leftHip = coords[23];
    final rightHip = coords[24];
    final hipCenter = [
      (leftHip[0] + rightHip[0]) / 2,
      (leftHip[1] + rightHip[1]) / 2,
      (leftHip[2] + rightHip[2]) / 2,
    ];

    final normalizedCoords = List.generate(33, (i) => [
      coords[i][0] - hipCenter[0],
      coords[i][1] - hipCenter[1],
      coords[i][2] - hipCenter[2],
    ]);

    // Scale by shoulder-to-shoulder distance (torso width proxy)
    final leftShoulder = normalizedCoords[11];
    final rightShoulder = normalizedCoords[12];
    final torsoLen = _euclideanDistance(leftShoulder, rightShoulder);

    final scaledCoords = torsoLen > 1e-6
        ? normalizedCoords
            .map((c) => [c[0] / torsoLen, c[1] / torsoLen, c[2] / torsoLen])
            .toList()
        : normalizedCoords;

    final features = <double>[];

    // Raw normalized coords — 33 * 3 = 99 dims
    for (final c in scaledCoords) {
      features.addAll(c);
    }

    // Bone vectors — 12 connections * 3 = 36 dims
    for (final conn in boneConnections) {
      final start = scaledCoords[conn[0]];
      final end = scaledCoords[conn[1]];
      for (int i = 0; i < 3; i++) {
        features.add(end[i] - start[i]);
      }
    }

    // Bone lengths squared — 12 dims
    for (final conn in boneConnections) {
      final start = scaledCoords[conn[0]];
      final end = scaledCoords[conn[1]];
      final dx = end[0] - start[0];
      final dy = end[1] - start[1];
      final dz = end[2] - start[2];
      features.add(dx * dx + dy * dy + dz * dz);
    }

    // Total: 99 + 36 + 12 = 147 dims
    return features;
  }

  /// Run inference on pose features.
  /// Returns map of class name → confidence score.
  Future<Map<String, double>> predict(List<double> features) async {
    if (!_isInitialized) {
      throw Exception('PoseClassifier not initialized');
    }
    if (features.length != _inputSize) {
      throw Exception('Expected $_inputSize features, got ${features.length}');
    }

    final input = [features];
    final output = List<List<double>>.filled(
      1,
      List.filled(_labels.length, 0.0),
    );
    _interpreter.run(input, output);

    final probabilities = <String, double>{};
    for (int i = 0; i < _labels.length; i++) {
      probabilities[_labels[i]] = output[0][i];
    }
    return probabilities;
  }

  /// Get top prediction as (label, confidence) record.
  Future<(String label, double confidence)> predictTop(
      List<double> features) async {
    final predictions = await predict(features);
    var maxLabel = '';
    var maxProb = 0.0;
    predictions.forEach((label, prob) {
      if (prob > maxProb) {
        maxProb = prob;
        maxLabel = label;
      }
    });
    return (maxLabel, maxProb);
  }

  void dispose() {
    if (_isInitialized) {
      _interpreter.close();
      _isInitialized = false;
    }
  }

  double _euclideanDistance(List<double> a, List<double> b) {
    double sum = 0.0;
    for (int i = 0; i < a.length; i++) {
      final diff = a[i] - b[i];
      sum += diff * diff;
    }
    return sqrt(sum);
  }
}
