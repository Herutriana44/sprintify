import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/performance_category.dart';
import '../providers/t_smart_state.dart';

class RecommendationScreen extends StatelessWidget {
  const RecommendationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TSmartState>();
    final r = state.lastRunResult;

    final recs = r == null
        ? <String>[]
        : _recommendationsFor(r.category, r.timeSeconds);

    final technique = r == null ? 0.0 : _scoreTechnique(r.category);
    final speed = r == null ? 0.0 : _scoreSpeed(r.timeSeconds);

    return Scaffold(
      appBar: AppBar(title: const Text('Rekomendasi (SPK)')),
      body: SafeArea(
        child: r == null
            ? const Center(child: Text('Tidak ada data untuk rekomendasi.'))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Sistem pendukung keputusan (rule-based demo)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Berdasarkan hasil tes untuk ${r.athleteName}.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _ScoreTile(
                          label: 'Teknik',
                          value: technique,
                          icon: Icons.accessibility_new,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ScoreTile(
                          label: 'Kecepatan',
                          value: speed,
                          icon: Icons.speed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Rekomendasi latihan',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ...recs.map(
                    (t) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Icon(Icons.check_circle_outline, color: Theme.of(context).colorScheme.primary),
                        title: Text(t),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go('/dashboard'),
                    child: const Text('Selesai'),
                  ),
                ],
              ),
      ),
    );
  }

  static List<String> _recommendationsFor(PerformanceCategory c, double time) {
    final list = <String>[
      'Pemanasan dinamis 10–15 menit sebelum tes.',
      'Latihan akselerasi 20–30 m dengan istirahat cukup.',
    ];
    switch (c) {
      case PerformanceCategory.baik:
        list.add('Pertahankan frekuensi latihan; tambah variasi agility ringan.');
        break;
      case PerformanceCategory.cukup:
        list.add('Perkuat latihan start dan dorongan pertama 10 meter.');
        list.add('Evaluasi panjang langkah dan ritme napas.');
        break;
      case PerformanceCategory.kurang:
        list.add('Fokus latihan start: reaksi dan posisi tubuh.');
        list.add('Perbaiki frekuensi langkah dengan drill teknik.');
        if (time > 11) {
          list.add('Tambahkan latihan kekuatan kaki dan core 2× pekan.');
        }
        break;
    }
    return list;
  }

  static double _scoreTechnique(PerformanceCategory c) {
    switch (c) {
      case PerformanceCategory.baik:
        return 8.6;
      case PerformanceCategory.cukup:
        return 6.8;
      case PerformanceCategory.kurang:
        return 5.2;
    }
  }

  static double _scoreSpeed(double timeSeconds) {
    final t = timeSeconds.clamp(6.0, 14.0);
    return (14 - t) / (14 - 6) * 10;
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final double value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              value.toStringAsFixed(1),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            Text(
              '/ 10',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
