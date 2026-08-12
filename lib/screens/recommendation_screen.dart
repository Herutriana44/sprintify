import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/t_smart_state.dart';
import '../services/analysis/recommendation_service.dart';

class RecommendationScreen extends StatelessWidget {
  const RecommendationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TSmartState>();
    final r = state.lastRunResult;

    if (r == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rekomendasi')),
        body: const Center(child: Text('Tidak ada data untuk rekomendasi.')),
      );
    }

    final bersediaScore = r.bersediaScore ?? 0.0;
    final berlariScore = r.berlariScore ?? 0.0;

    final recs = r.recommendations.isNotEmpty
        ? r.recommendations
        : RecommendationService().generate(
            bersediaScore: bersediaScore,
            berlariScore: berlariScore,
          );

    final overallLabel = RecommendationService().overallLabel(
      bersediaScore: bersediaScore,
      berlariScore: berlariScore,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Rekomendasi Latihan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Rekomendasi untuk ${r.athleteName}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Berdasarkan analisis posisi bersedia dan berlari.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),

            // Skor ringkasan
            Row(
              children: [
                Expanded(
                  child: _ScoreTile(
                    label: 'Bersedia',
                    value: bersediaScore,
                    icon: Icons.accessibility_new,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ScoreTile(
                    label: 'Berlari',
                    value: berlariScore,
                    icon: Icons.directions_run,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Label keseluruhan
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.emoji_events_outlined,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Performa keseluruhan: $overallLabel',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
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
                  leading: Icon(
                    Icons.check_circle_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(t),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Selesai'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final double value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value.toStringAsFixed(1),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
            ),
            Text(
              '/ 100',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: value / 100,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              minHeight: 6,
            ),
          ],
        ),
      ),
    );
  }
}
