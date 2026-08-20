import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Membaca konfigurasi Firebase dari file .env sehingga tidak perlu
/// meng-commit google-services.json atau GoogleService-Info.plist.
///
/// Pastikan .env sudah diload sebelum memanggil [firebaseOptions].
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => FirebaseOptions(
        apiKey: dotenv.get('FIREBASE_API_KEY', fallback: ''),
        appId: dotenv.get('FIREBASE_APP_ID', fallback: ''),
        messagingSenderId:
            dotenv.get('FIREBASE_MESSAGING_SENDER_ID', fallback: ''),
        projectId: dotenv.get('FIREBASE_PROJECT_ID', fallback: ''),
        authDomain: dotenv.get('FIREBASE_AUTH_DOMAIN', fallback: ''),
        storageBucket: dotenv.get('FIREBASE_STORAGE_BUCKET', fallback: ''),
      );
}
