import 'exercise_type.dart';
import 'performance_category.dart';

/// Hasil sesi tes kebugaran fisik.
class ExerciseResult {
  const ExerciseResult({
    required this.athleteId,
    required this.athleteName,
    required this.exerciseType,
    required this.repCount,
    required this.durationSeconds,
    required this.category,
    required this.recordedAt,
    this.analysisNote,
    this.recommendations = const [],
  });

  final String athleteId;
  final String athleteName;

  /// Jenis exercise yang dinilai.
  final ExerciseType exerciseType;

  /// Jumlah repetisi yang berhasil dihitung.
  final int repCount;

  /// Durasi rekaman dalam detik.
  final int durationSeconds;

  /// Kategori performa berdasarkan jumlah repetisi.
  final PerformanceCategory category;

  /// Waktu rekaman dilakukan.
  final DateTime recordedAt;

  /// Narasi evaluasi dari Gemini AI.
  final String? analysisNote;

  /// Daftar rekomendasi latihan.
  final List<String> recommendations;

  @override
  String toString() {
    return '''
{
  "athleteId": "$athleteId",
  "athleteName": "$athleteName",
  "exerciseType": "${exerciseType.name}",
  "repCount": $repCount,
  "durationSeconds": $durationSeconds,
  "category": "${category.name}",
  "recordedAt": "${recordedAt.toIso8601String()}"
}''';
  }
}
