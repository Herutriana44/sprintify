import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/t_smart_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Tangkap error Flutter
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('FLUTTER ERROR: ${details.exception}');
  };

  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✓ Environment variables loaded successfully');
  } catch (e) {
    debugPrint('⚠ Warning: Failed to load .env file: $e');
    debugPrint('⚠ Proceeding with default/empty environment variables');
  }

  runApp(
    ChangeNotifierProvider<TSmartState>(
      create: (_) => TSmartState(),
      child: const TSmartApp(),
    ),
  );
}
