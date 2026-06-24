import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../pose/pose_detection_isolate.dart';
import '../pose/pose_classifier.dart';
import '../pose/classifier_isolate.dart';

/// Result dari processing satu frame.
class FrameProcessingResult {
  const FrameProcessingResult({
    required this.frameIndex,
    required this.timestamp,
    required this.poseDetected,
    required this.classification,
    this.serializedLandmarks,
  });

  final int frameIndex;
  final Duration timestamp;
  final bool poseDetected;
  final FramePoseResult? classification;
  final Map<String, Map<String, double>>? serializedLandmarks;
}

/// Service untuk batch processing video frames secara parallel.
class BatchFrameProcessor {
  BatchFrameProcessor({
    required this.referencePoses,
    this.poseDetectionPoolSize = 2,
  });

  final Map<String, dynamic> referencePoses;
  final int poseDetectionPoolSize;

  PoseDetectionPool? _posePool;
  ClassifierIsolate? _classifierIsolate;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize pose detection pool
    _posePool = PoseDetectionPool(poolSize: poseDetectionPoolSize);
    await _posePool!.initialize();

    // Initialize classifier isolate
    _classifierIsolate = ClassifierIsolate();
    await _classifierIsolate!.start(referencePoses);

    _initialized = true;
  }

  /// Process batch CameraImage frames secara parallel.
  ///
  /// Mengembalikan Stream hasil processing untuk setiap frame.
  Stream<FrameProcessingResult> processCameraImageBatch(
    List<CameraImageFrame> frames, {
    int batchSize = 4,
  }) async* {
    if (!_initialized) {
      throw StateError('BatchFrameProcessor not initialized');
    }

    for (int i = 0; i < frames.length; i += batchSize) {
      final end = (i + batchSize < frames.length) ? i + batchSize : frames.length;
      final batch = frames.sublist(i, end);

      // Convert CameraImage to PoseDetectionInput
      final inputs = <PoseDetectionInput>[];
      for (final frame in batch) {
        final input = _cameraImageToDetectionInput(frame.image, frame.metadata);
        if (input != null) {
          inputs.add(input);
        }
      }

      // Detect poses in parallel
      final detectionResults = await _posePool!.detectPosesBatch(inputs);

      // Classify poses in parallel
      for (int j = 0; j < detectionResults.length; j++) {
        final detection = detectionResults[j];
        final frame = batch[j];

        FramePoseResult? classification;
        Map<String, Map<String, double>>? landmarks;

        if (detection.serializedLandmarks.isNotEmpty) {
          landmarks = detection.serializedLandmarks.first;
          final classifyResult = await _classifierIsolate!.classify(landmarks);
          classification = FramePoseResult(
            label: classifyResult.label,
            score: classifyResult.score,
          );
        }

        yield FrameProcessingResult(
          frameIndex: frame.index,
          timestamp: frame.timestamp,
          poseDetected: detection.poses.isNotEmpty,
          classification: classification,
          serializedLandmarks: landmarks,
        );
      }
    }
  }

  /// Process single CameraImage (untuk live camera stream).
  Future<FrameProcessingResult> processSingleFrame({
    required CameraImage image,
    required CameraImageMetadata metadata,
    required int frameIndex,
    required Duration timestamp,
  }) async {
    if (!_initialized) {
      throw StateError('BatchFrameProcessor not initialized');
    }

    final input = _cameraImageToDetectionInput(image, metadata);
    if (input == null) {
      return FrameProcessingResult(
        frameIndex: frameIndex,
        timestamp: timestamp,
        poseDetected: false,
        classification: null,
      );
    }

    // Detect pose
    final detection = await _posePool!.detectPoses(input);

    FramePoseResult? classification;
    Map<String, Map<String, double>>? landmarks;

    if (detection.serializedLandmarks.isNotEmpty) {
      landmarks = detection.serializedLandmarks.first;
      final classifyResult = await _classifierIsolate!.classify(landmarks);
      classification = FramePoseResult(
        label: classifyResult.label,
        score: classifyResult.score,
      );
    }

    return FrameProcessingResult(
      frameIndex: frameIndex,
      timestamp: timestamp,
      poseDetected: detection.poses.isNotEmpty,
      classification: classification,
      serializedLandmarks: landmarks,
    );
  }

  bool get isInitialized => _initialized;

  void dispose() {
    _posePool?.dispose();
    _classifierIsolate?.dispose();
    _initialized = false;
  }

  // Helper: Convert CameraImage to PoseDetectionInput
  PoseDetectionInput? _cameraImageToDetectionInput(
    CameraImage image,
    CameraImageMetadata metadata,
  ) {
    final Uint8List bytes;

    if (Platform.isAndroid) {
      // NV21 format
      if (image.planes.length == 1) {
        bytes = image.planes[0].bytes;
      } else if (image.planes.length >= 2) {
        final yPlane = image.planes[0].bytes;
        final uvPlane = image.planes[1].bytes;
        final combined = Uint8List(yPlane.length + uvPlane.length);
        combined.setAll(0, yPlane);
        combined.setAll(yPlane.length, uvPlane);
        bytes = combined;
      } else {
        return null;
      }

      return PoseDetectionInput(
        imageBytes: bytes,
        width: image.width,
        height: image.height,
        format: InputImageFormat.nv21,
        rotation: metadata.rotation,
        bytesPerRow: image.planes[0].bytesPerRow,
      );
    } else {
      // iOS: BGRA8888
      if (image.planes.length != 1) return null;
      bytes = image.planes[0].bytes;

      return PoseDetectionInput(
        imageBytes: bytes,
        width: image.width,
        height: image.height,
        format: InputImageFormat.bgra8888,
        rotation: metadata.rotation,
        bytesPerRow: image.planes[0].bytesPerRow,
      );
    }
  }
}

/// Wrapper untuk CameraImage dengan metadata.
class CameraImageFrame {
  const CameraImageFrame({
    required this.index,
    required this.timestamp,
    required this.image,
    required this.metadata,
  });

  final int index;
  final Duration timestamp;
  final CameraImage image;
  final CameraImageMetadata metadata;
}

/// Metadata untuk CameraImage processing.
class CameraImageMetadata {
  const CameraImageMetadata({
    required this.rotation,
    required this.sensorOrientation,
  });

  final InputImageRotation rotation;
  final int sensorOrientation;
}
