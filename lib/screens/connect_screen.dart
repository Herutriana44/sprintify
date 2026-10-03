import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/t_smart_state.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _idController = TextEditingController();

  Future<void> _connect() async {
    final id = _idController.text.trim();
    if (id.isEmpty) return;

    final dbRef = FirebaseDatabase.instance.ref().child(id);
    final snapshot = await dbRef.get();

    if (snapshot.exists) {
      if (mounted) {
        Provider.of<TSmartState>(context, listen: false).setIdConnect(id);
        context.go('/dashboard');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ID Koneksi tidak valid')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hubungkan Device')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _idController,
              decoration: const InputDecoration(labelText: 'ID Koneksi'),
            ),
            ElevatedButton(
              onPressed: _connect,
              child: const Text('Hubungkan'),
            ),
          ],
        ),
      ),
    );
  }
}
