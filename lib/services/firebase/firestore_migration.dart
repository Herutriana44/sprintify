import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Mengelola migrasi skema Firestore dan seeding data awal.
///
/// Cara kerja:
/// - Dokumen `_meta/schema` menyimpan versi skema saat ini.
/// - Saat [runMigrations] dipanggil, versi dibandingkan dengan [_targetVersion].
/// - Tiap migration function dijalankan secara berurutan jika belum dijalankan.
class FirestoreMigration {
  FirestoreMigration({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const int _targetVersion = 1;
  static const String _metaCollection = '_meta';
  static const String _schemaDoc = 'schema';

  DocumentReference<Map<String, dynamic>> get _schemaRef =>
      _db.collection(_metaCollection).doc(_schemaDoc);

  /// Jalankan semua migrasi yang belum diterapkan untuk user [uid].
  /// Dipanggil setelah login berhasil.
  Future<void> runMigrations(String uid) async {
    try {
      final snap = await _schemaRef.get();
      final currentVersion = snap.exists
          ? (snap.data()?['version'] as int? ?? 0)
          : 0;

      if (currentVersion >= _targetVersion) {
        debugPrint('Firestore: schema sudah up-to-date (v$currentVersion)');
        return;
      }

      debugPrint(
          'Firestore: migrasi dari v$currentVersion ke v$_targetVersion');

      if (currentVersion < 1) {
        await _migrate_v1(uid);
      }

      await _schemaRef.set({
        'version': _targetVersion,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': uid,
      });

      debugPrint('Firestore: migrasi selesai (v$_targetVersion)');
    } catch (e) {
      debugPrint('Firestore migration error: $e');
    }
  }

  /// Migrasi v1: buat struktur dasar koleksi users/{uid}/athletes
  /// dan users/{uid}/results jika belum ada.
  Future<void> _migrate_v1(String uid) async {
    debugPrint('Firestore: menjalankan migrasi v1 untuk uid=$uid');

    final userDoc = _db.collection('users').doc(uid);
    final userSnap = await userDoc.get();

    if (!userSnap.exists) {
      await userDoc.set({
        'createdAt': FieldValue.serverTimestamp(),
        'schemaVersion': 1,
      }, SetOptions(merge: true));
    }

    final athletesSnap =
        await userDoc.collection('athletes').limit(1).get();
    final resultsSnap =
        await userDoc.collection('results').limit(1).get();

    debugPrint(
      'Firestore v1: athletes=${athletesSnap.docs.length}, '
      'results=${resultsSnap.docs.length}',
    );
  }

  /// Seed data atlet demo untuk user baru (hanya jika belum ada data).
  Future<void> seedIfEmpty(String uid) async {
    try {
      final athletesCol =
          _db.collection('users').doc(uid).collection('athletes');
      final snap = await athletesCol.limit(1).get();

      if (snap.docs.isNotEmpty) {
        debugPrint('Firestore seeder: data sudah ada, skip seeding');
        return;
      }

      debugPrint('Firestore seeder: menyemai data demo untuk uid=$uid');

      final batch = _db.batch();

      final seedAthletes = [
        {
          'name': 'Budi Santoso',
          'age': 16,
          'gender': 'Laki-laki',
          'className': 'X IPA 1',
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'name': 'Siti Aminah',
          'age': 15,
          'gender': 'Perempuan',
          'className': 'X IPA 2',
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'name': 'Ahmad Fauzi',
          'age': 17,
          'gender': 'Laki-laki',
          'className': 'XI IPS 1',
          'createdAt': FieldValue.serverTimestamp(),
        },
      ];

      for (final data in seedAthletes) {
        batch.set(athletesCol.doc(), data);
      }

      await batch.commit();
      debugPrint(
          'Firestore seeder: ${seedAthletes.length} atlet demo berhasil dibuat');
    } catch (e) {
      debugPrint('Firestore seeder error: $e');
    }
  }

  /// Reset semua data user (athletes + results) — hanya untuk keperluan dev/test.
  /// PERINGATAN: operasi ini tidak bisa di-undo.
  Future<void> clearUserData(String uid) async {
    debugPrint('Firestore: menghapus semua data untuk uid=$uid');

    final userDoc = _db.collection('users').doc(uid);

    await _deleteCollection(userDoc.collection('athletes'));
    await _deleteCollection(userDoc.collection('results'));

    debugPrint('Firestore: data user dihapus');
  }

  Future<void> _deleteCollection(
      CollectionReference<Map<String, dynamic>> col) async {
    const batchSize = 20;
    QuerySnapshot<Map<String, dynamic>> snap;
    do {
      snap = await col.limit(batchSize).get();
      if (snap.docs.isEmpty) break;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } while (snap.docs.length == batchSize);
  }
}
