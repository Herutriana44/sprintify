import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/t_smart_state.dart';

/// RoomScreen — ruang tunggu sebelum rekaman dimulai.
///
/// Alur:
///   1. Kedua device (start & finish) masuk ke room dengan roomId yang sama.
///   2. Device start menekan "Mulai Rekaman" → Firebase: room/{id}/startStatus = true
///   3. Semua device yang sudah ada di room langsung auto-navigate ke RecordingScreen.
///   4. RecordingScreen start berjalan duluan (rekam fase bersedia & berlari).
///   5. Setelah startRecordingDone = true di Firebase, finish device mulai merekam.
class RoomScreen extends StatefulWidget {
  final String roomId;

  const RoomScreen({super.key, required this.roomId});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late final DatabaseReference _roomRef;
  StreamSubscription<DatabaseEvent>? _roomSub;

  bool _partnerConnected = false;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _roomRef = FirebaseDatabase.instance.ref('rooms/${widget.roomId}');
    _announcePresence();
    _listenRoom();
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _leaveRoom();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Firebase presence
  // ---------------------------------------------------------------------------

  Future<void> _announcePresence() async {
    final state = context.read<TSmartState>();
    final role = state.deviceRole ?? 'unknown';

    // Tulis kehadiran device ini ke Firebase
    await _roomRef.child('presence/$role').set({
      'online': true,
      'joinedAt': ServerValue.timestamp,
    });

    // Hapus kehadiran saat disconnect
    await _roomRef.child('presence/$role/online').onDisconnect().set(false);

    // Update state lokal
    if (role == 'start') {
      state.setStartDeviceReady(true);
    } else {
      state.setFinishDeviceReady(true);
    }
  }

  Future<void> _leaveRoom() async {
    final role = context.read<TSmartState>().deviceRole ?? 'unknown';
    await _roomRef.child('presence/$role/online').set(false);
  }

  // ---------------------------------------------------------------------------
  // Listen Firebase room changes
  // ---------------------------------------------------------------------------

  void _listenRoom() {
    _roomSub = _roomRef.onValue.listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value;
      if (data == null) return;

      final map = Map<String, dynamic>.from(data as Map);

      // Cek kehadiran kedua device
      final presence = map['presence'] as Map? ?? {};
      final startOnline =
          (presence['start'] as Map?)?['online'] == true;
      final finishOnline =
          (presence['finish'] as Map?)?['online'] == true;

      setState(() {
        _partnerConnected = startOnline && finishOnline;
      });

      // Update state provider dari data Firebase
      final appState = context.read<TSmartState>();
      final startStatus = map['startStatus'] == true;
      final startRecordingDone = map['startRecordingDone'] == true;

      if (startStatus && !appState.startStatus) {
        appState.setStartStatus(true);
      }
      if (startRecordingDone && !appState.startRecordingDone) {
        appState.setStartRecordingDone(true);
      }

      // ── Auto-navigate ke RecordingScreen ──────────────────────────────────
      // Syarat: startStatus = true DAN belum navigating
      if (startStatus && !_navigating) {
        _navigating = true;
        // Beri sedikit jeda agar UI render update terakhir
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            context.push('/recording');
          }
        });
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Start device actions
  // ---------------------------------------------------------------------------

  Future<void> _triggerStart() async {
    // Tulis startStatus ke Firebase → semua device yang listen akan auto-navigate
    await _roomRef.update({
      'startStatus': true,
      'startedAt': ServerValue.timestamp,
    });
    if (mounted) {
      context.read<TSmartState>().setStartStatus(true);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TSmartState>();
    final isStart = state.deviceRole == 'start';
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Room'),
        actions: [
          // Tombol salin Room ID untuk di-share ke finish device
          if (isStart)
            IconButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.roomId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Room ID disalin!')),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              tooltip: 'Salin Room ID',
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Room ID display ──────────────────────────────────────────
              _buildRoomIdCard(scheme),
              const SizedBox(height: 24),

              // ── Status koneksi kedua device ──────────────────────────────
              _buildConnectionStatus(state, scheme),
              const SizedBox(height: 24),

              // ── Role info ────────────────────────────────────────────────
              _buildRoleCard(isStart, scheme),
              const Spacer(),

              // ── Tombol aksi ──────────────────────────────────────────────
              if (isStart) _buildStartButton(state),
              if (!isStart) _buildFinishWaiting(state, scheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomIdCard(ColorScheme scheme) {
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        child: Column(
          children: [
            Text(
              'Room ID',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onPrimaryContainer.withOpacity(0.7),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.roomId,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
                color: scheme.onPrimaryContainer,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(TSmartState state, ColorScheme scheme) {
    return Row(
      children: [
        _buildDeviceStatus(
          label: 'Start',
          online: state.startDeviceReady,
          scheme: scheme,
        ),
        const SizedBox(width: 12),
        Icon(Icons.sync_alt_rounded,
            color: _partnerConnected ? scheme.primary : scheme.outline),
        const SizedBox(width: 12),
        _buildDeviceStatus(
          label: 'Finish',
          online: state.finishDeviceReady,
          scheme: scheme,
        ),
      ],
    );
  }

  Widget _buildDeviceStatus({
    required String label,
    required bool online,
    required ColorScheme scheme,
  }) {
    return Expanded(
      child: Card(
        color: online
            ? scheme.secondaryContainer
            : scheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(
                online ? Icons.smartphone_rounded : Icons.smartphone_outlined,
                color: online ? scheme.secondary : scheme.outline,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: online
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: online ? Colors.green : scheme.outline,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    online ? 'Terhubung' : 'Menunggu...',
                    style: TextStyle(
                      fontSize: 11,
                      color: online
                          ? scheme.onSecondaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(bool isStart, ColorScheme scheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isStart ? Icons.flag_outlined : Icons.emoji_events_outlined,
              color: scheme.primary,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isStart ? 'Device Start' : 'Device Finish',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isStart
                        ? 'Posisikan di garis start. Tekan "Mulai" untuk memulai rekaman.'
                        : 'Posisikan di garis finish. Rekaman dimulai otomatis setelah start device memulai.',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
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

  Widget _buildStartButton(TSmartState state) {
    // Jika startStatus sudah true (misal dari sesi sebelumnya), tampil loading
    if (state.startStatus) {
      return Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            'Memulai rekaman...',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return FilledButton.icon(
      onPressed: _partnerConnected ? _triggerStart : null,
      icon: const Icon(Icons.videocam_rounded),
      label: const Text('Mulai Rekaman'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildFinishWaiting(TSmartState state, ColorScheme scheme) {
    if (state.startStatus) {
      return Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            'Start device memulai... segera masuk ke rekaman.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Menunggu start device memulai...',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
