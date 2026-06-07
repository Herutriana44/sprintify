import 'package:flutter/material.dart';

class AssessmentWaitingScreen extends StatelessWidget {
  final List<String> logs;

  const AssessmentWaitingScreen({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sedang Menganalisis...')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            const Text('Harap tunggu, sistem sedang memproses penilaian...'),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: logs.length,
                  itemBuilder: (context, index) => Text(
                    logs[index],
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
