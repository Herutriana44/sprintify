import 'performance_category.dart';

class RunResult {
  RunResult({
    required this.athleteId,
    required this.athleteName,
    required this.timeSeconds,
    required this.category,
    required this.startMarkSeconds,
    required this.finishMarkSeconds,
    required this.stepCount,
    required this.avgSpeedKmh,
    required this.recordedAt,
    this.analysisNote,
    this.bersediaScore,
    this.berlariScore,
    this.recommendations = const [],
    this.bersediaFrameCount = 0,
    this.berlariFrameCount = 0,
  });

  final String athleteId;
  final String athleteName;
  final double timeSeconds;
  final PerformanceCategory category;
  final double startMarkSeconds;
  final double finishMarkSeconds;
  final int stepCount;
  final double avgSpeedKmh;
  final DateTime recordedAt;

  /// Narasi analisis dari Gemini AI.
  final String? analysisNote;

  /// Skor rata-rata posisi bersedia (0–100).
  final double? bersediaScore;

  /// Skor rata-rata posisi berlari (0–100).
  final double? berlariScore;

  /// Daftar rekomendasi dari logika kondisional.
  final List<String> recommendations;

  /// Jumlah frame yang terklasifikasi sebagai bersedia.
  final int bersediaFrameCount;

  /// Jumlah frame yang terklasifikasi sebagai berlari.
  final int berlariFrameCount;

  @override
  String toString() {
    return '''
{
  "athleteId": "$athleteId",
  "athleteName": "$athleteName",
  "timeSeconds": $timeSeconds,
  "category": "${category.name}",
  "bersediaScore": ${bersediaScore?.toStringAsFixed(1) ?? 'null'},
  "berlariScore": ${berlariScore?.toStringAsFixed(1) ?? 'null'},
  "bersediaFrameCount": $bersediaFrameCount,
  "berlariFrameCount": $berlariFrameCount,
  "recordedAt": "${recordedAt.toIso8601String()}"
}''';
  }
}
