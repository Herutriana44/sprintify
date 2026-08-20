import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Loads label mapping from assets/models/pose_labels.json.
/// Returns a list where index corresponds to class index in the TFLite model.
Future<List<String>> loadPoseLabels() async {
  final jsonString = await rootBundle.loadString('assets/models/pose_labels.json');
  final Map<String, dynamic> map = json.decode(jsonString);
  // The JSON saved by Python script is a dict of label->index.
  // We need an ordered list where list[index] = label.
  final int maxIdx = map.values.map((v) => v as int).fold(0, (a, b) => a > b ? a : b);
  final List<String> ordered = List.filled(maxIdx + 1, 'unknown');
  map.forEach((label, idx) {
    ordered[idx as int] = label;
  });
  return ordered;
}
