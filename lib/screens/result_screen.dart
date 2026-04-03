import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/sprintify_state.dart';
import '../widgets/performance_chip.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SprintifyState>();
    final r = state.lastRunResult;
    if (r == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hasil lari')),
        body: const Center(child: Text('Belum ada hasil. Jalankan tes dari beranda.')),
      );
    }

    final spots = [
      const FlSpot(0, 0),
      FlSpot(1, r.timeSeconds.clamp(5, 20)),
      FlSpot(2, (r.timeSeconds * 0.95).clamp(5, 20)),
      FlSpot(3, r.timeSeconds.clamp(5, 20)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hasil lari'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              r.athleteName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Waktu tempuh',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${r.timeSeconds.toStringAsFixed(1)} detik',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          'Kategori: ',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        PerformanceChip(category: r.category),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Grafik sederhana (demo)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: true),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (v, m) {
                              const labels = ['', 'T1', 'T2', 'T3'];
                              final i = v.toInt().clamp(0, 3);
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  labels[i],
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            getTitlesWidget: (v, m) => Text(
                              v.toStringAsFixed(0),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: Theme.of(context).colorScheme.primary,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/analysis'),
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('Analisis detail (CV)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/recommendation'),
              icon: const Icon(Icons.lightbulb_outline),
              label: const Text('Rekomendasi latihan (SPK)'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Kembali ke beranda'),
            ),
          ],
        ),
      ),
    );
  }
}
