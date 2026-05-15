import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter/material.dart';

class PoseManager {
  final PoseDetector _poseDetector = PoseDetector(options: PoseDetectorOptions());

  Future<List<Pose>> processImage(InputImage inputImage) async {
    return await _poseDetector.processImage(inputImage);
  }

  void dispose() {
    _poseDetector.close();
  }
}
