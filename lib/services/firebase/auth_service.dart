import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'firestore_service.dart';
import 'firestore_migration.dart';

class AuthService extends ChangeNotifier {
  AuthService({
    FirebaseAuth? auth,
    FirestoreService? firestoreService,
    FirestoreMigration? migration,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestoreService = firestoreService ?? FirestoreService(),
        _migration = migration ?? FirestoreMigration();

  final FirebaseAuth _auth;
  final FirestoreService _firestoreService;
  final FirestoreMigration _migration;
  GoogleSignIn? _googleSignIn;
  GoogleSignIn get _gsi => _googleSignIn ??= GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
  String? get uid => _auth.currentUser?.uid;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ---------------------------------------------------------------------------
  // Email / Password
  // ---------------------------------------------------------------------------

  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _postLoginSetup(cred.user!);
      return AuthResult.success(cred.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure('[${e.code}] ${e.message ?? e.code}');
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }

  Future<AuthResult> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user!.updateDisplayName(name.trim());
      await _postLoginSetup(cred.user!, name: name.trim());
      return AuthResult.success(cred.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure('[${e.code}] ${e.message ?? e.code}');
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Google Sign-In
  // ---------------------------------------------------------------------------

  Future<AuthResult> signInWithGoogle() async {
    try {
      final googleUser = await _gsi.signIn();
      if (googleUser == null) {
        return AuthResult.failure('Login Google dibatalkan.');
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final cred = await _auth.signInWithCredential(credential);
      await _postLoginSetup(cred.user!, name: googleUser.displayName);
      return AuthResult.success(cred.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure('[${e.code}] ${e.message ?? e.code}');
    } catch (e) {
      return AuthResult.failure(e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Sign Out
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    // Only sign out from Google if GSI was ever initialized (i.e. user logged
    // in via Google). Calling _gsi.signOut() for email-only sessions would
    // instantiate a fresh GoogleSignIn object and may throw on iOS.
    final futures = <Future<void>>[_auth.signOut()];
    if (_googleSignIn != null) {
      futures.add(_googleSignIn!.signOut());
    }
    await Future.wait(futures);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Post-login setup: buat user doc, jalankan migration, seed jika perlu
  // ---------------------------------------------------------------------------

  Future<void> _postLoginSetup(User user, {String? name}) async {
    // Profile creation — non-fatal: user proceeds to /role-selection regardless,
    // but log clearly so failures are visible in debug output.
    try {
      await _firestoreService.createUserIfNotExists(
        uid: user.uid,
        email: user.email ?? '',
        name: name ?? user.displayName ?? '',
      );
    } catch (e) {
      debugPrint('AuthService _postLoginSetup: profile creation failed — $e');
    }

    // Migration and seed — non-fatal by design.
    try {
      await _migration.runMigrations(user.uid);
      await _migration.seedIfEmpty(user.uid);
    } catch (e) {
      debugPrint('AuthService _postLoginSetup: migration/seed failed — $e');
    }

    notifyListeners();
  }

}

/// Hasil operasi autentikasi.
class AuthResult {
  const AuthResult._({required this.success, this.user, this.error});

  factory AuthResult.success(User user) =>
      AuthResult._(success: true, user: user);

  factory AuthResult.failure(String error) =>
      AuthResult._(success: false, error: error);

  final bool success;
  final User? user;
  final String? error;
}
