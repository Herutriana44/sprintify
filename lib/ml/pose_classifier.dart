import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Class to run pose classification inference with TFLite model.
/// Classifies poses as "bersedia" (ready) or "berlari" (running).
class PoseClassifier {
  late Interpreter _interpreter;
  late List<String> _labels;
  late int _inputSize;
  bool _isInitialized = false;

  /// Bone connections used in training (same as train_pose_classifier.py)
  static const List<List<int>> BONE_CONNECTIONS = [
    [11, 13], [13, 15], // left arm
    [12, 14], [14, 16], // right arm
    [11, 12],            // shoulders
    [11, 23], [12, 24],  // torso sides
    [23, 25], [25, 27],  // left leg
    [24, 26], [26, 28],  // right leg
    [23, 24],            // hips
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

  /// Extract normalized bone-vector features from MLKit Pose object.
  /// Matches the Python training script exactly.
  /// Returns flat feature vector matching training features.
  List<double> extractFeaturesFromPose(Pose pose) {
    final landmarks = pose.landmarks;
    if (landmarks.length != 33) {
      throw Exception('Expected 33 landmarks, got ${landmarks.length}');
    }

    // Extract raw coordinates
    final coords = List.generate(33, (i) {
      final type = [
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.rightShoulder,
        PoseLandmarkType.leftElbow,
        PoseLandmarkType.rightElbow,
        PoseLandmarkType.leftWrist,
        PoseLandmarkType.rightWrist,
        PoseLandmarkType.leftHip,
        PoseLandmarkType.rightHip,
        PoseLandmarkType.leftKnee,
        PoseLandmarkType.rightKnee,
        PoseLandmarkType.leftAnkle,
        PoseLandmarkType.rightAnkle,
        PoseLandmarkType.pic,
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
        PoseLandmarkType.pelvis,
        PoseLandmarkType.leftPelvis,
        PoseLandmarkType.rightPelvis,
        PoseLandmarkType.leftHeel,
        PoseLandmarkType.rightHeel,
        PoseLandmarkType.leftFootIndex,
        PoseLandmarkType.rightFootIndex,
        PoseLandmarkType.spine,
        PoseLandmarkType.leftCollar,
        PoseLandmarkType.rightCollar,
      ][i];
      final lm = landmarks[type];
      return [lm?.x ?? 0.0, lm?.y ?? 0.0, lm?.z ?? 0.0];
    });

    // Normalize: translate so hip center is origin
    final leftHip = coords[6]; // index 23 in MediaPipe
    final rightHip = coords[7]; // index 24 in MediaPipe
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

    // Normalize: scale by torso length
    final leftShoulder = normalizedCoords[0]; // index 11
    final rightShoulder = normalizedCoords[1]; // index 12
    final torsoLen = _euclideanDistance(
      [leftShoulder[0], leftShoulder[1], leftShoulder[2]],
      [0, 0, 0],
    );

    final scaledCoords = torsoLen > 1e-6
        ? normalizedCoords.map((c) => [
            c[0] / torsoLen,
            c[1] / torsoLen,
            c[2] / torsoLen,
          ]).toList()
        : normalizedCoords;

    final features = <double>[];

    // Raw normalized coords — 33 * 3 = 99 dims
    for (final c in scaledCoords) {
      features.addAll(c);
    }

    // Bone vectors for each connection
    for (final conn in BONE_CONNECTIONS) {
      final start = scaledCoords[conn[0]];
      final end = scaledCoords[conn[1]];
      for (int i = 0; i < 3; i++) {
        features.add(end[i] - start[i]);
      }
    }

    // Bone lengths squared
    for (final conn in BONE_CONNECTIONS) {
      final start = scaledCoords[conn[0]];
      final end = scaledCoords[conn[1]];
      final dx = end[0] - start[0];
      final dy = end[1] - start[1];
      final dz = end[2] - start[2];
      features.add(dx * dx + dy * dy + dz * dz);
    }

    return features;
  }

  /// Run inference on pose features.
  /// Returns map of class name → confidence.
  Future<Map<String, double>> predict(List<double> features) async {
    if (!_isInitialized) {
      throw Exception('PoseClassifier not initialized');
    }

    if (features.length != _inputSize) {
      throw Exception('Expected $_inputSize features, got ${features.length}');
    }

    final input = [features];
    final output = List<List<double>>.filled(1, List.filled(_labels.length, 0.0));
    _interpreter.run(input, output);

    final probabilities = <String, double>{};
    for (int i = 0; i < _labels.length; i++) {
      probabilities[_labels[i]] = output[0][i];
    }

    return probabilities;
  }

  /// Get top prediction.
  Future<(String label, double confidence)> predictTop(List<double> features) async {
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

  /// Dispose interpreter when done.
  void dispose() {
    _interpreter.close();
    _isInitialized = false;
  }

  double _euclideanDistance(List<double> a, List<double> b) {
    final sum = a.asMap().entries.fold<double>(
      0,
      (acc, entry) {
        final diff = entry.value - b[entry.key];
        return acc + diff * diff;
      },
    );
    return sum.sqrt();
  }
}
