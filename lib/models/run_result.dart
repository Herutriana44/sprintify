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
}
