import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/sprintify_state.dart';

class AnalysisDetailScreen extends StatelessWidget {
  const AnalysisDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SprintifyState>();
    final r = state.lastRunResult;

    return Scaffold(
      appBar: AppBar(title: const Text('Analisis detail')),
      body: SafeArea(
        child: r == null
            ? const Center(child: Text('Tidak ada data analisis.'))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Computer vision (demo)',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Frame penting & indikator teknis.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _FrameCard(label: 'Start', seconds: r.startMarkSeconds)),
                      const SizedBox(width: 12),
                      Expanded(child: _FrameCard(label: 'Finish', seconds: r.finishMarkSeconds)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Metrik',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 12),
                          _metricRow(context, 'Jumlah langkah (est.)', '${r.stepCount}'),
                          _metricRow(
                            context,
                            'Kecepatan rata-rata',
                            '${r.avgSpeedKmh.toStringAsFixed(1)} km/jam',
                          ),
                          _metricRow(
                            context,
                            'Waktu tempuh',
                            '${r.timeSeconds.toStringAsFixed(1)} d',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Highlight posisi tubuh: pada produksi, ditampilkan overlay '
                        'skeleton/keypoints dari model CV.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Log Analisis (JSON)',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          final data = r.toString();
                          Clipboard.setData(ClipboardData(text: data));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Log berhasil disalin')),
                          );
                        },
                      ),
                    ],
                  ),
                  Container(
                    height: 150,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        r.toString(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.push('/recommendation'),
                    child: const Text('Lanjut ke rekomendasi'),
                  ),
                ],
              ),
      ),
    );
  }

  static Widget _metricRow(BuildContext context, String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: Theme.of(context).textTheme.bodyMedium),
          Text(v, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _FrameCard extends StatelessWidget {
  const _FrameCard({required this.label, required this.seconds});

  final String label;
  final double seconds;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).colorScheme.surfaceContainerHigh,
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                    ],
                  ),
                ),
                child: Icon(
                  Icons.image_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    '@ ${seconds.toStringAsFixed(2)} s',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
