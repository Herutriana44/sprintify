import 'dart:io';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image/image.dart' as img;

/// CLI tool to detect pose from a single image file.
/// Usage: dart bin/detect_pose.dart <image_path>
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart bin/detect_pose.dart <image_path>');
    exit(1);
  }

  final imagePath = args[0];
  final file = File(imagePath);
  if (!await file.exists()) {
    print('Error: File not found at $imagePath');
    exit(1);
  }

  // 1. Initialize Pose Detector
  final inputImage = InputImage.fromFilePath(imagePath);
  final poseDetector = PoseDetector(options: PoseDetectorOptions());

  try {
    // 2. Process Image
    final poses = await poseDetector.processImage(inputImage);

    if (poses.isEmpty) {
      print('No poses detected in the image.');
    } else {
      final pose = poses.first;
      
      // Output 1: Vector Values (Landmarks)
      print('--- Detected Pose Landmarks ---');
      for (final landmark in pose.landmarks.values) {
        print('${landmark.type.name}: x=${landmark.x.toStringAsFixed(2)}, y=${landmark.y.toStringAsFixed(2)}, z=${landmark.z.toStringAsFixed(2)}');
      }

      // Output 2: Annotated Image
      final rawBytes = await file.readAsBytes();
      final image = img.decodeImage(rawBytes);
      if (image != null) {
        for (final landmark in pose.landmarks.values) {
          img.drawCircle(image, landmark.x.toInt(), landmark.y.toInt(), 5, img.ColorRgb8(255, 0, 0));
        }
        
        final outputPath = 'output_annotated_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await File(outputPath).writeAsBytes(img.encodeJpg(image));
        print('\n--- Success ---');
        print('Annotated image saved to: $outputPath');
      }
    }
  } catch (e) {
    print('Error processing pose: $e');
  } finally {
    poseDetector.close();
  }
}
