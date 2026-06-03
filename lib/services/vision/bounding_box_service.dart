import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class BoundingBoxService {
  // Logika untuk menghitung atau menggambar bounding box dari landmark pose
  static Rect getBoundingBox(Pose pose) {
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final landmark in pose.landmarks.values) {
      if (landmark.x < minX) minX = landmark.x;
      if (landmark.x > maxX) maxX = landmark.x;
      if (landmark.y < minY) minY = landmark.y;
      if (landmark.y > maxY) maxY = landmark.y;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}
