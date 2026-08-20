import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/t_smart_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('FLUTTER ERROR: ${details.exception}');
  };

  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✓ Environment variables loaded');
  } catch (e) {
    debugPrint('⚠ Warning: Failed to load .env: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<TSmartState>(
          create: (_) => TSmartState(),
        ),
      ],
      child: const TSmartApp(),
    ),
  );
}
