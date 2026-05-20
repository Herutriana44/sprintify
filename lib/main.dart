import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/sprintify_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Tangkap error Flutter
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('FLUTTER ERROR: ${details.exception}');
  };

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('DOTENV ERROR: $e');
  }

  runApp(
    ChangeNotifierProvider<SprintifyState>(
      create: (_) => SprintifyState(),
      child: const SprintifyApp(),
    ),
  );
}
