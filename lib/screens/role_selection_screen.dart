import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/t_smart_state.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  String _generateIdConnect() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Start device: buat room baru di Firebase lalu masuk ke RoomScreen
  Future<void> _onStartTap(BuildContext context) async {
    final state = Provider.of<TSmartState>(context, listen: false);
    final roomId = _generateIdConnect();

    // Buat node room di Firebase Realtime DB
    final roomRef = FirebaseDatabase.instance.ref('rooms/$roomId');
    await roomRef.set({
      'createdAt': ServerValue.timestamp,
      'startStatus': false,
      'startRecordingDone': false,
      'finishRecordingDone': false,
    });

    state.setDeviceRole('start');
    state.setIdConnect(roomId);
    state.resetRoomState();
    state.setStartDeviceReady(true);

    if (context.mounted) {
      context.push('/room/$roomId');
    }
  }

  /// Finish device: minta user input roomId lalu validasi di Firebase
  Future<void> _onFinishTap(BuildContext context) async {
    final roomId = await _showRoomIdDialog(context);
    if (roomId == null || roomId.isEmpty) return;

    final roomRef = FirebaseDatabase.instance.ref('rooms/$roomId');
    final snapshot = await roomRef.get();

    if (!context.mounted) return;

    if (!snapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room ID tidak ditemukan.')),
      );
      return;
    }

    final state = Provider.of<TSmartState>(context, listen: false);
    state.setDeviceRole('finish');
    state.setIdConnect(roomId);
    state.resetRoomState();
    state.setFinishDeviceReady(true);

    if (context.mounted) {
      context.push('/room/$roomId');
    }
  }

  Future<String?> _showRoomIdDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Masukkan Room ID'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 4,
          textCapitalization: TextCapitalization.none,
          decoration: const InputDecoration(
            labelText: 'Room ID (4 karakter)',
            prefixIcon: Icon(Icons.meeting_room_rounded),
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Gabung'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Pilih Peran')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text(
                'Tentukan peran device ini',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Dua device dibutuhkan: satu di garis start, satu di garis finish.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // ── Start Device Card ─────────────────────────────────────────
              _RoleCard(
                icon: Icons.flag_rounded,
                color: scheme.primary,
                title: 'Start Device',
                description:
                    'Device di garis start. Buat room baru dan bagikan kode ke finish device.',
                actionLabel: 'Buat Room & Mulai',
                onTap: () => _onStartTap(context),
              ),
              const SizedBox(height: 16),

              // ── Finish Device Card ────────────────────────────────────────
              _RoleCard(
                icon: Icons.emoji_events_rounded,
                color: scheme.secondary,
                title: 'Finish Device',
                description:
                    'Device di garis finish. Masukkan kode room dari start device untuk bergabung.',
                actionLabel: 'Gabung Room',
                onTap: () => _onFinishTap(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(backgroundColor: color),
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
