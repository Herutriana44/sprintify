import 'dart:io';

/// Data yang dikumpulkan selama rekaman dan diteruskan ke layar pemrosesan.
class PendingAnalysis {
  const PendingAnalysis({
    required this.videoPath,
    required this.timerSeconds,
    required this.bersediaScores,
    required this.berlariScores,
    this.bestBersediaFrame,
    this.bestBerlariFrame,
    this.sampleFramePaths = const [],
  });

  /// Path file video yang direkam/dipilih.
  final String videoPath;

  /// Durasi timer rekaman (detik).
  final int timerSeconds;

  /// Skor tiap frame yang terklasifikasi sebagai posisi bersedia.
  final List<double> bersediaScores;

  /// Skor tiap frame yang terklasifikasi sebagai posisi berlari.
  final List<double> berlariScores;

  /// Frame terbaik untuk posisi bersedia (digunakan Gemini).
  final File? bestBersediaFrame;

  /// Frame terbaik untuk posisi berlari (digunakan Gemini).
  final File? bestBerlariFrame;

  /// Semua frame sample yang disimpan selama rekaman (pose terdeteksi).
  final List<String> sampleFramePaths;

  /// Skor rata-rata posisi bersedia (null jika tidak ada frame bersedia).
  double? get avgBersediaScore {
    if (bersediaScores.isEmpty) return null;
    return bersediaScores.reduce((a, b) => a + b) / bersediaScores.length;
  }

  /// Skor rata-rata posisi berlari (null jika tidak ada frame berlari).
  double? get avgBerlariScore {
    if (berlariScores.isEmpty) return null;
    return berlariScores.reduce((a, b) => a + b) / berlariScores.length;
  }

  /// Frame terbaik yang tersedia (untuk dikirim ke Gemini).
  List<File> get bestFrames {
    final frames = <File>[];
    if (bestBersediaFrame != null) frames.add(bestBersediaFrame!);
    if (bestBerlariFrame != null) frames.add(bestBerlariFrame!);
    return frames;
  }

  /// Pilih hingga [maxImages] frame untuk dikirim ke Gemini.
  ///
  /// Prioritas: frame terbaik dulu, lalu sample frame yang pose-nya terdeteksi.
  /// Maksimal [maxImages] gambar (default 10).
  List<File> selectImagesForAnalysis({int maxImages = 10}) {
    final selected = <File>[];

    // Prioritaskan best frames
    if (bestBersediaFrame != null) selected.add(bestBersediaFrame!);
    if (bestBerlariFrame != null) selected.add(bestBerlariFrame!);

    // Tambahkan sample frames hingga mencapai maxImages
    for (final path in sampleFramePaths) {
      if (selected.length >= maxImages) break;
      final file = File(path);
      if (file.existsSync() && !selected.any((f) => f.path == path)) {
        selected.add(file);
      }
    }

    return selected;
  }
}
