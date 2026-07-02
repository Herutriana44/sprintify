import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

// ---------------------------------------------------------------------------
// Input/Output types
// ---------------------------------------------------------------------------

class PoseDetectionInput {
  const PoseDetectionInput({
    required this.imageBytes,
    required this.width,
    required this.height,
    required this.format,
    required this.rotation,
    required this.bytesPerRow,
  });

  final Uint8List imageBytes;
  final int width;
  final int height;
  final InputImageFormat format;
  final InputImageRotation rotation;
  final int bytesPerRow;
}

class PoseDetectionOutput {
  const PoseDetectionOutput({
    required this.poses,
    required this.serializedLandmarks,
  });

  final List<SerializedPose> poses;
  final List<Map<String, Map<String, double>>> serializedLandmarks;
}

class SerializedPose {
  const SerializedPose({required this.landmarks});

  final Map<String, Map<String, double>> landmarks;
}

// ---------------------------------------------------------------------------
// PoseDetectionPool — in-process async wrapper
//
// Catatan: google_mlkit_pose_detection memakai MethodChannel yang hanya bisa
// diakses dari root isolate. Memindahkannya ke background isolate menyebabkan
// error "BackgroundIsolateBinaryMessenger.instance value is invalid".
// Karena PoseDetector.processImage() sudah asynchronous dan men-delegasikan
// inference ke native side (tidak memblok UI thread), kita jalankan di
// main isolate. Klasifikasi & file I/O tetap di background isolate.
// ---------------------------------------------------------------------------

class PoseDetectionPool {
  PoseDetectionPool({this.poolSize = 2});

  final int poolSize;
  final PoseDetector _detector = PoseDetector(options: PoseDetectorOptions());
  bool _initialized = false;

  Future<void> initialize() async {
    _initialized = true;
  }

  Future<PoseDetectionOutput> detectPoses(PoseDetectionInput input) async {
    if (!_initialized) {
      throw StateError('PoseDetectionPool not initialized');
    }

    final inputImage = InputImage.fromBytes(
      bytes: input.imageBytes,
      metadata: InputImageMetadata(
        size: Size(input.width.toDouble(), input.height.toDouble()),
        rotation: input.rotation,
        format: input.format,
        bytesPerRow: input.bytesPerRow,
      ),
    );

    final poses = await _detector.processImage(inputImage);

    final serializedPoses = <SerializedPose>[];
    final serializedLandmarks = <Map<String, Map<String, double>>>[];

    for (final pose in poses) {
      final landmarks = <String, Map<String, double>>{};
      for (final entry in pose.landmarks.entries) {
        final key = _landmarkTypeToString(entry.key);
        if (key != null) {
          landmarks[key] = {
            'x': entry.value.x,
            'y': entry.value.y,
            'z': entry.value.z,
          };
        }
      }
      serializedPoses.add(SerializedPose(landmarks: landmarks));
      serializedLandmarks.add(landmarks);
    }

    return PoseDetectionOutput(
      poses: serializedPoses,
      serializedLandmarks: serializedLandmarks,
    );
  }

  Future<List<PoseDetectionOutput>> detectPosesBatch(
    List<PoseDetectionInput> inputs,
  ) {
    return Future.wait(inputs.map((input) => detectPoses(input)));
  }

  Stream<PoseDetectionOutput> detectPosesStream(
    List<PoseDetectionInput> inputs, {
    int batchSize = 4,
  }) async* {
    for (int i = 0; i < inputs.length; i += batchSize) {
      final end = (i + batchSize < inputs.length) ? i + batchSize : inputs.length;
      final batch = inputs.sublist(i, end);
      final results = await detectPosesBatch(batch);
      for (final result in results) {
        yield result;
      }
    }
  }

  bool get isInitialized => _initialized;

  void dispose() {
    _detector.close();
    _initialized = false;
  }
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

String? _landmarkTypeToString(PoseLandmarkType type) {
  switch (type) {
    case PoseLandmarkType.nose:
      return 'nose';
    case PoseLandmarkType.leftShoulder:
      return 'left_shoulder';
    case PoseLandmarkType.rightShoulder:
      return 'right_shoulder';
    case PoseLandmarkType.leftElbow:
      return 'left_elbow';
    case PoseLandmarkType.rightElbow:
      return 'right_elbow';
    case PoseLandmarkType.leftWrist:
      return 'left_wrist';
    case PoseLandmarkType.rightWrist:
      return 'right_wrist';
    case PoseLandmarkType.leftHip:
      return 'left_hip';
    case PoseLandmarkType.rightHip:
      return 'right_hip';
    case PoseLandmarkType.leftKnee:
      return 'left_knee';
    case PoseLandmarkType.rightKnee:
      return 'right_knee';
    case PoseLandmarkType.leftAnkle:
      return 'left_ankle';
    case PoseLandmarkType.rightAnkle:
      return 'right_ankle';
    case PoseLandmarkType.leftEar:
      return 'left_ear';
    case PoseLandmarkType.rightEar:
      return 'right_ear';
    case PoseLandmarkType.leftEye:
      return 'left_eye';
    case PoseLandmarkType.rightEye:
      return 'right_eye';
    case PoseLandmarkType.leftPinky:
      return 'left_pinky';
    case PoseLandmarkType.rightPinky:
      return 'right_pinky';
    case PoseLandmarkType.leftIndex:
      return 'left_index';
    case PoseLandmarkType.rightIndex:
      return 'right_index';
    case PoseLandmarkType.leftThumb:
      return 'left_thumb';
    case PoseLandmarkType.rightThumb:
      return 'right_thumb';
    case PoseLandmarkType.leftHeel:
      return 'left_heel';
    case PoseLandmarkType.rightHeel:
      return 'right_heel';
    case PoseLandmarkType.leftFootIndex:
      return 'left_foot_index';
    case PoseLandmarkType.rightFootIndex:
      return 'right_foot_index';
    default:
      return null;
  }
}
