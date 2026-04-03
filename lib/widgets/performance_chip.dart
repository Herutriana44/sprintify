import 'package:flutter/material.dart';

import '../models/performance_category.dart';

class PerformanceChip extends StatelessWidget {
  const PerformanceChip({super.key, required this.category});

  final PerformanceCategory category;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color bg, Color fg) = switch (category) {
      PerformanceCategory.baik => (scheme.primaryContainer, scheme.onPrimaryContainer),
      PerformanceCategory.cukup => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      PerformanceCategory.kurang => (scheme.errorContainer, scheme.onErrorContainer),
    };
    return Chip(
      label: Text(
        category.label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
      backgroundColor: bg,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
