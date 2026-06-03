import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class DetectionService {
  // Tempat menaruh logika deteksi objek atau pose lainnya di masa depan
  static bool isPersonVisible(Pose pose) {
    // Implementasi logika apakah orang terlihat jelas dalam frame
    return pose.landmarks.isNotEmpty;
  }
}
