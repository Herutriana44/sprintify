import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseClassifier {
  late Interpreter _interpreter;
  late List<String> _labels;
  static const int _inputSize = 147; // Must match Python training output
  bool _isInitialized = false;

  /// Initialize the classifier with TFLite model
  Future<void> initialize({
    required String modelPath,
    required List<String> labels,
  }) async {
    try {
      _interpreter = await Interpreter.fromAsset(modelPath);
      _labels = labels;
      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize PoseClassifier: $e');
    }
  }

  /// Extract normalized pose features from MLKit Pose object
  List<double> extractFeaturesFromPose(Pose pose) {
    final landmarks = pose.landmarks;
    if (landmarks.length != 33) { // 33 landmarks in MLKit
      throw Exception('Expected 33 landmarks, got ${landmarks.length}');
    }

    final coords = Float32List(99);
    int idx = 0;
    for (final landmark in landmarks.values) {
      coords[idx++] = landmark.x;
      coords[idx++] = landmark.y;
      coords[idx++] = landmark.z;
    }

    // Normalize: center on hip, scale by torso length
    final leftHip = landmarks[PoseLandmarkType.leftHip]!;
    final rightHip = landmarks[PoseLandmarkType.rightHip]!;
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder]!;
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder]!;

    final hipCenter = [
      (leftHip.x + rightHip.x) / 2,
      (leftHip.y + rightHip.y) / 2,
      (leftHip.z + rightHip.z) / 2,
    ];

    // Translate to origin
    for (int i = 0; i < 99; i += 3) {
      coords[i] -= hipCenter[0];
      coords[i + 1] -= hipCenter[1];
      coords[i + 2] -= hipCenter[2];
    }

    // Scale by torso length
    final shoulderCenter = [
      (leftShoulder.x + rightShoulder.x) / 2 - hipCenter[0],
      (leftShoulder.y + rightShoulder.y) / 2 - hipCenter[1],
      (leftShoulder.z + rightShoulder.z) / 2 - hipCenter[2],
    ];
    final torsoLen = (shoulderCenter[0] * shoulderCenter[0] +
        shoulderCenter[1] * shoulderCenter[1] +
        shoulderCenter[2] * shoulderCenter[2]).toDouble();

    if (torsoLen > 1e-6) {
      final scale = 1.0 / (torsoLen.toDouble());
      for (int i = 0; i < 99; i++) {
        coords[i] *= scale;
      }
    }

    // Build features (simplified for demo; expand to match Python training)
    final features = <double>[];
    for (int i = 0; i < 99; i++) {
      features.add(coords[i].toDouble());
    }

    // Pad to expected input size if needed
    while (features.length < _inputSize) {
      features.add(0.0);
    }

    return features.sublist(0, _inputSize);
  }

  /// Run inference on pose features
  /// Returns: {label: probability}
  Future<Map<String, double>> predict(List<double> features) async {
    if (!_isInitialized) {
      throw Exception('PoseClassifier not initialized');
    }

    if (features.length != _inputSize) {
      throw Exception('Expected $_inputSize features, got ${features.length}');
    }

    // Prepare input
    final input = [features];

    // Run inference
    final output = List<List<double>>.filled(1, List.filled(_labels.length, 0.0));
    _interpreter.run(input, output);

    // Parse results
    final predictions = <String, double>{};
    final probs = output[0];
    for (int i = 0; i < _labels.length; i++) {
      predictions[_labels[i]] = probs[i];
    }

    return predictions;
  }

  /// Get top prediction
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

  void dispose() {
    _interpreter.close();
    _isInitialized = false;
  }
}
