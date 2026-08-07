import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/performance_category.dart';
import '../providers/t_smart_state.dart';
import '../services/firebase/auth_service.dart';
import '../widgets/summary_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TSmartState>();
    final last = state.lastRunResult;
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : user?.email?.split('@').first ?? 'pelatih';

    final perf = last != null
        ? '${last.timeSeconds.toStringAsFixed(1)} d — ${last.category.label}'
        : 'Belum ada tes';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beranda'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: state.loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (state.error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        state.error!,
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  Text(
                    'Halo, $displayName',
                    style:
                        Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ringkasan aktivitas dan akses cepat.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 20),
                  SummaryCard(
                    title: 'Total percobaan',
                    value: '${state.totalAttempts}',
                    icon: Icons.analytics_outlined,
                    subtitle: 'Tersimpan di cloud',
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

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Keluar?'),
        content: const Text('Sesi kamu akan diakhiri.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AuthService>().signOut();
      if (context.mounted) context.go('/login');
    }
  }
}
