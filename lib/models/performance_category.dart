enum PerformanceCategory {
  baik,
  cukup,
  kurang,
}

extension PerformanceCategoryLabel on PerformanceCategory {
  String get label {
    switch (this) {
      case PerformanceCategory.baik:
        return 'Baik';
      case PerformanceCategory.cukup:
        return 'Cukup';
      case PerformanceCategory.kurang:
        return 'Kurang';
    }
  }
}
