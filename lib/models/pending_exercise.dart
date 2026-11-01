import 'dart:io';

import 'exercise_type.dart';

/// Data yang dikumpulkan selama sesi exercise dan diteruskan ke layar pemrosesan.
class PendingExercise {
  const PendingExercise({
    required this.exerciseType,
    required this.repCount,
    required this.durationSeconds,
    this.sampleFramePaths = const [],
    this.videoPath,
  });

  /// Jenis exercise yang dilakukan.
  final ExerciseType exerciseType;

  /// Jumlah repetisi yang terhitung selama sesi.
  final int repCount;

  /// Durasi rekaman dalam detik.
  final int durationSeconds;

  /// Path frame-frame sample yang disimpan selama sesi.
  final List<String> sampleFramePaths;

  /// Path video rekaman (opsional, jika rekaman video aktif).
  final String? videoPath;

  /// Pilih hingga [maxImages] frame sample untuk dikirim ke Gemini.
  List<File> selectImagesForAnalysis({int maxImages = 10}) {
    final selected = <File>[];
    for (final path in sampleFramePaths) {
      if (selected.length >= maxImages) break;
      final file = File(path);
      if (file.existsSync()) {
        selected.add(file);
      }
    }
    return selected;
  }
}
