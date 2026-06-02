import 'dart:io';
import 'package:flutter/material.dart';

class TempResultScreen extends StatelessWidget {
  final String videoPath;

  const TempResultScreen({super.key, required this.videoPath});

  @override
  Widget build(BuildContext context) {
    final fileName = videoPath.split('/').last;

    return Scaffold(
      appBar: AppBar(title: const Text('Hasil Sementara')),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          Text('Informasi Video', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 20),
          ListTile(
            title: const Text('Nama File'),
            subtitle: Text(fileName),
            leading: const Icon(Icons.video_file),
          ),
          const Divider(),
          ListTile(
            title: const Text('Lokasi File (Path)'),
            subtitle: Text(videoPath),
            leading: const Icon(Icons.folder),
          ),
          const SizedBox(height: 30),
          Text('Sample Frames', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          ...List.generate(5, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              height: 150,
              color: Colors.grey[300],
              child: Center(child: Text('Frame ${index + 1}')),
            );
          }),
          const SizedBox(height: 30),
          Center(
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kembali'),
            ),
          ),
        ],
      ),
    );
  }
}
