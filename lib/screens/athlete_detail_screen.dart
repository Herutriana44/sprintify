import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/sprintify_state.dart';

class AthleteDetailScreen extends StatelessWidget {
  const AthleteDetailScreen({super.key, required this.athleteId});

  final String athleteId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SprintifyState>();
    final a = state.getAthleteById(athleteId);
    if (a == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Atlet')),
        body: const Center(child: Text('Data tidak ditemukan.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail atlet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/athletes/${a.id}/edit'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Nama'),
              subtitle: Text(a.name, style: Theme.of(context).textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.cake_outlined),
              title: const Text('Umur'),
              subtitle: Text('${a.age} tahun'),
            ),
            ListTile(
              leading: const Icon(Icons.wc),
              title: const Text('Jenis kelamin'),
              subtitle: Text(a.gender),
            ),
            if (a.className != null)
              ListTile(
                leading: const Icon(Icons.class_outlined),
                title: const Text('Kelas'),
                subtitle: Text(a.className!),
              ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => context.push('/test-prep'),
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Gunakan untuk tes lari'),
            ),
          ],
        ),
      ),
    );
  }
}
