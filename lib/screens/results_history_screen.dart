import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/sprintify_state.dart';
import '../widgets/performance_chip.dart';

class ResultsHistoryScreen extends StatelessWidget {
  const ResultsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SprintifyState>();
    final list = state.history;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat hasil'),
        actions: [
          if (state.lastRunResult != null)
            TextButton(
              onPressed: () => context.push('/result'),
              child: const Text('Detail terakhir'),
            ),
        ],
      ),
      body: SafeArea(
        child: list.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Belum ada riwayat. Selesaikan tes dari Beranda.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (context, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final r = list[i];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.timer_outlined),
                      title: Text(r.athleteName),
                      subtitle: Text(
                        '${r.timeSeconds.toStringAsFixed(1)} d • ${_fmt(r.recordedAt)}',
                      ),
                      trailing: PerformanceChip(category: r.category),
                      onTap: () => context.push('/result'),
                    ),
                  );
                },
              ),
      ),
    );
  }

  static String _fmt(DateTime d) {
    return '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }
}
