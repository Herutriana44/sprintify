import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/t_smart_state.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  String _generateIdConnect() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(4, (index) => chars[random.nextInt(chars.length)]).join();
  }

  @override
  Widget build(BuildContext context) {
    final smartState = Provider.of<TSmartState>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Pilih Peran')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                smartState.setDeviceRole('start');
                smartState.setIdConnect(_generateIdConnect());
                context.go('/dashboard');
              },
              child: const Text('Start Device'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                smartState.setDeviceRole('finish');
                context.push('/connect');
              },
              child: const Text('Finish Device'),
            ),
          ],
        ),
      ),
    );
  }
}
