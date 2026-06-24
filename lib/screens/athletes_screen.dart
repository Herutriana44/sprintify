import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/t_smart_state.dart';

class AthletesScreen extends StatelessWidget {
  const AthletesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TSmartState>();
    final list = state.athletes;

    return Scaffold(
      appBar: AppBar(title: const Text('Data Atlet')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/athletes/new'),
        icon: const Icon(Icons.person_add),
        label: const Text('Tambah'),
      ),
      body: SafeArea(
        child: list.isEmpty
            ? Center(
                child: Text(
                  'Belum ada atlet. Tap Tambah.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (context, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final a = list[i];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(a.name.isNotEmpty ? a.name[0].toUpperCase() : '?'),
                      ),
                      title: Text(a.name),
                      subtitle: Text(
                        '${a.age} th • ${a.gender}${a.className != null ? ' • ${a.className}' : ''}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'edit') {
                            context.push('/athletes/${a.id}/edit');
                          } else if (v == 'delete') {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('Hapus atlet?'),
                                content: Text('Hapus ${a.name} dari daftar demo?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: const Text('Batal'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(c, true),
                                    child: const Text('Hapus'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true && context.mounted) {
                              state.deleteAthlete(a.id);
                            }
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Hapus')),
                        ],
                      ),
                      onTap: () => context.push('/athletes/${a.id}'),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
