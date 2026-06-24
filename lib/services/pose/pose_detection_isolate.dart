import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../isolate/isolate_pool.dart';

// ---------------------------------------------------------------------------
// Input/Output types untuk pose detection isolate
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

/// Serialized pose data yang bisa di-transfer antar isolate.
class SerializedPose {
  const SerializedPose({
    required this.landmarks,
  });

  final Map<String, Map<String, double>> landmarks;
}

// ---------------------------------------------------------------------------
// Isolate entry point
// ---------------------------------------------------------------------------

void _poseDetectionIsolateEntry(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  // Initialize pose detector di isolate ini
  final poseDetector = PoseDetector(options: PoseDetectorOptions());

  receivePort.listen((dynamic message) async {
    if (message is _IsolateTask<PoseDetectionInput>) {
      try {
        final input = message.input;

        // Buat InputImage dari bytes
        final inputImage = InputImage.fromBytes(
          bytes: input.imageBytes,
          metadata: InputImageMetadata(
            size: Size(input.width.toDouble(), input.height.toDouble()),
            rotation: input.rotation,
            format: input.format,
            bytesPerRow: input.bytesPerRow,
          ),
        );

        // Detect poses
        final poses = await poseDetector.processImage(inputImage);

        // Serialize hasil
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

        final output = PoseDetectionOutput(
          poses: serializedPoses,
          serializedLandmarks: serializedLandmarks,
        );

        mainSendPort.send(_IsolateResponse<PoseDetectionOutput>(
          taskId: message.taskId,
          result: output,
        ));
      } catch (e, stack) {
        mainSendPort.send(_IsolateError(
          taskId: message.taskId,
          error: 'Pose detection error: $e\n$stack',
        ));
      }
    }
  });
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Pool untuk parallel pose detection di multiple isolates.
class PoseDetectionPool {
  PoseDetectionPool({this.poolSize = 2});

  final int poolSize;
  late final IsolatePool<PoseDetectionInput, PoseDetectionOutput> _pool;

  Future<void> initialize() async {
    _pool = IsolatePool<PoseDetectionInput, PoseDetectionOutput>(
      workerEntryPoint: _poseDetectionIsolateEntry,
      poolSize: poolSize,
    );
    await _pool.initialize();
  }

  /// Process single image untuk pose detection.
  Future<PoseDetectionOutput> detectPoses(PoseDetectionInput input) {
    return _pool.execute(input);
  }

  /// Process batch images secara parallel.
  Future<List<PoseDetectionOutput>> detectPosesBatch(
    List<PoseDetectionInput> inputs,
  ) {
    return _pool.executeAll(inputs);
  }

  /// Process stream of frames dengan batch processing.
  Stream<PoseDetectionOutput> detectPosesStream(
    List<PoseDetectionInput> inputs, {
    int batchSize = 4,
  }) {
    return _pool.executeBatch(inputs, batchSize: batchSize);
  }

  bool get isInitialized => _pool.isInitialized;

  void dispose() {
    _pool.dispose();
  }
}

// ---------------------------------------------------------------------------
// Helper functions
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

// Internal message types (reused from isolate_pool pattern)
class _IsolateTask<I> {
  _IsolateTask({required this.taskId, required this.input});
  final int taskId;
  final I input;
}

class _IsolateResponse<O> {
  _IsolateResponse({required this.taskId, required this.result});
  final int taskId;
  final O result;
}

class _IsolateError {
  _IsolateError({required this.taskId, required this.error});
  final int taskId;
  final Object error;
}
