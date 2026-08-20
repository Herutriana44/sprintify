import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/athlete.dart';
import '../../models/performance_category.dart';
import '../../models/run_result.dart';

/// Skema koleksi Firestore:
///
///   users/{uid}
///     name: String
///     email: String
///     createdAt: Timestamp
///
///   users/{uid}/athletes/{athleteId}
///     name: String
///     age: int
///     gender: String
///     className: String?
///     createdAt: Timestamp
///
///   users/{uid}/results/{resultId}
///     athleteId: String
///     athleteName: String
///     timeSeconds: double
///     category: String          // 'baik' | 'cukup' | 'kurang'
///     startMarkSeconds: double
///     finishMarkSeconds: double
///     stepCount: int
///     avgSpeedKmh: double
///     recordedAt: Timestamp
///     analysisNote: String?
///     bersediaScore: double?
///     berlariScore: double?
///     recommendations: List<String>
///     bersediaFrameCount: int
///     berlariFrameCount: int

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> _athletesCol(String uid) =>
      _db.collection('users').doc(uid).collection('athletes');

  CollectionReference<Map<String, dynamic>> _resultsCol(String uid) =>
      _db.collection('users').doc(uid).collection('results');

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  // ---------------------------------------------------------------------------
  // User
  // ---------------------------------------------------------------------------

  Future<void> createUserIfNotExists({
    required String uid,
    required String email,
    String? name,
  }) async {
    final doc = _userDoc(uid);
    final snap = await doc.get();
    if (!snap.exists) {
      await doc.set({
        'name': name ?? '',
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<Map<String, dynamic>?> getUser(String uid) async {
    final snap = await _userDoc(uid).get();
    return snap.data();
  }

  // ---------------------------------------------------------------------------
  // Athletes
  // ---------------------------------------------------------------------------

  Future<List<Athlete>> fetchAthletes(String uid) async {
    final snap = await _athletesCol(uid)
        .orderBy('createdAt', descending: false)
        .get();
    return snap.docs.map((doc) => _athleteFromDoc(doc.id, doc.data())).toList();
  }

  Stream<List<Athlete>> watchAthletes(String uid) {
    return _athletesCol(uid)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => _athleteFromDoc(doc.id, doc.data()))
            .toList());
  }

  Future<String> addAthlete(String uid, Athlete athlete) async {
    final ref = await _athletesCol(uid).add(_athleteToMap(athlete));
    return ref.id;
  }

  Future<void> updateAthlete(String uid, Athlete athlete) async {
    await _athletesCol(uid).doc(athlete.id).update(_athleteToMap(athlete));
  }

  Future<void> deleteAthlete(String uid, String athleteId) async {
    await _athletesCol(uid).doc(athleteId).delete();
  }

  // ---------------------------------------------------------------------------
  // Run Results
  // ---------------------------------------------------------------------------

  Future<List<RunResult>> fetchResults(String uid) async {
    final snap = await _resultsCol(uid)
        .orderBy('recordedAt', descending: true)
        .get();
    return snap.docs.map((doc) => _resultFromDoc(doc.data())).toList();
  }

  Stream<List<RunResult>> watchResults(String uid) {
    return _resultsCol(uid)
        .orderBy('recordedAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => _resultFromDoc(doc.data())).toList());
  }

  Future<void> addResult(String uid, RunResult result) async {
    await _resultsCol(uid).add(_resultToMap(result));
  }

  // ---------------------------------------------------------------------------
  // Serialization helpers
  // ---------------------------------------------------------------------------

  static Athlete _athleteFromDoc(String id, Map<String, dynamic> data) {
    return Athlete(
      id: id,
      name: data['name'] as String? ?? '',
      age: data['age'] as int? ?? 0,
      gender: data['gender'] as String? ?? '',
      className: data['className'] as String?,
    );
  }

  static Map<String, dynamic> _athleteToMap(Athlete a) => {
        'name': a.name,
        'age': a.age,
        'gender': a.gender,
        'className': a.className,
        'createdAt': FieldValue.serverTimestamp(),
      };

  static RunResult _resultFromDoc(Map<String, dynamic> data) {
    final categoryStr = data['category'] as String? ?? 'kurang';
    final category = PerformanceCategory.values.firstWhere(
      (c) => c.name == categoryStr,
      orElse: () => PerformanceCategory.kurang,
    );
    final recordedAt = data['recordedAt'];
    final DateTime dt = recordedAt is Timestamp
        ? recordedAt.toDate()
        : DateTime.now();

    return RunResult(
      athleteId: data['athleteId'] as String? ?? '',
      athleteName: data['athleteName'] as String? ?? '',
      timeSeconds: (data['timeSeconds'] as num?)?.toDouble() ?? 0,
      category: category,
      startMarkSeconds: (data['startMarkSeconds'] as num?)?.toDouble() ?? 0,
      finishMarkSeconds: (data['finishMarkSeconds'] as num?)?.toDouble() ?? 0,
      stepCount: data['stepCount'] as int? ?? 0,
      avgSpeedKmh: (data['avgSpeedKmh'] as num?)?.toDouble() ?? 0,
      recordedAt: dt,
      analysisNote: data['analysisNote'] as String?,
      bersediaScore: (data['bersediaScore'] as num?)?.toDouble(),
      berlariScore: (data['berlariScore'] as num?)?.toDouble(),
      recommendations: List<String>.from(data['recommendations'] ?? []),
      bersediaFrameCount: data['bersediaFrameCount'] as int? ?? 0,
      berlariFrameCount: data['berlariFrameCount'] as int? ?? 0,
    );
  }

  static Map<String, dynamic> _resultToMap(RunResult r) => {
        'athleteId': r.athleteId,
        'athleteName': r.athleteName,
        'timeSeconds': r.timeSeconds,
        'category': r.category.name,
        'startMarkSeconds': r.startMarkSeconds,
        'finishMarkSeconds': r.finishMarkSeconds,
        'stepCount': r.stepCount,
        'avgSpeedKmh': r.avgSpeedKmh,
        'recordedAt': FieldValue.serverTimestamp(),
        'analysisNote': r.analysisNote,
        'bersediaScore': r.bersediaScore,
        'berlariScore': r.berlariScore,
        'recommendations': r.recommendations,
        'bersediaFrameCount': r.bersediaFrameCount,
        'berlariFrameCount': r.berlariFrameCount,
      };
}
