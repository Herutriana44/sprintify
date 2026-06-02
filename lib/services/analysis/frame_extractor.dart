import 'dart:io';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

class FrameExtractor {
  static Future<List<File>> extractFrames(String videoPath, int count) async {
    final tempDir = await getTemporaryDirectory();
    final List<File> frames = [];

    // Mengambil 5 frame dengan interval 1 detik (1000ms)
    for (int i = 0; i < count; i++) {
      try {
        final fileName = await VideoThumbnail.thumbnailFile(
          video: videoPath,
          thumbnailPath: tempDir.path,
          imageFormat: ImageFormat.JPEG,
          timeMs: (i * 1000), 
          quality: 50,
        );
        if (fileName != null) {
          frames.add(File(fileName));
        }
      } catch (e) {
        // Log error atau abaikan jika gagal ekstrak satu frame
        print('Gagal ekstrak frame ke-$i: $e');
      }
    }
    return frames;
  }
}
