import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/t_smart_state.dart';
import '../widgets/summary_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TSmartState>();
    final last = state.lastRunResult;

    final perf = last != null
        ? '${last.timeSeconds.toStringAsFixed(1)} d — ${last.category.label}'
        : 'Belum ada tes';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beranda'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Selamat datang',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ringkasan aktivitas dan akses cepat.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            SummaryCard(
              title: 'Total percobaan',
              value: '${state.totalAttempts}',
              icon: Icons.analytics_outlined,
              subtitle: 'Tersimpan di sesi ini',
            ),
            const SizedBox(height: 12),
            SummaryCard(
              title: 'Performa terakhir',
              value: perf,
              icon: Icons.speed_rounded,
              subtitle: last != null
                  ? last.athleteName
                  : 'Mulai tes untuk melihat hasil',
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => context.push('/test-prep'),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Mulai Tes Lari'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/results-history'),
              icon: const Icon(Icons.history),
              label: const Text('Lihat Hasil'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/athletes'),
              icon: const Icon(Icons.groups_outlined),
              label: const Text('Data Atlet / Siswa'),
            ),
          ],
        ),
      ),
    );
  }
}
