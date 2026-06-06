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
}
