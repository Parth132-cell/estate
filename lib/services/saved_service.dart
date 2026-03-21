import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum ComparisonToggleResult { added, removed, limitReached }

class SavedService {
  static const int maxComparisonCount = 3;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _saved => _db.collection('saved');

  String _docId(String propertyId) => '${_uid}_$propertyId';

  Future<void> toggleFavorite(String propertyId) async {
    final docRef = _saved.doc(_docId(propertyId));
    final doc = await docRef.get();

    if (doc.exists) {
      final data = doc.data() ?? <String, dynamic>{};
      final currentFav = data['isFavorite'] == true;
      final currentCompare = data['forComparison'] == true;
      final newFav = !currentFav;

      if (!newFav && !currentCompare) {
        await docRef.delete();
      } else {
        await docRef.set({
          'userId': _uid,
          'propertyId': propertyId,
          'isFavorite': newFav,
          'forComparison': currentCompare,
          'createdAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      return;
    }

    await docRef.set({
      'userId': _uid,
      'propertyId': propertyId,
      'isFavorite': true,
      'forComparison': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<ComparisonToggleResult> toggleComparison(String propertyId) async {
    final docRef = _saved.doc(_docId(propertyId));
    final doc = await docRef.get();

    if (doc.exists) {
      final data = doc.data() ?? <String, dynamic>{};
      final currentFav = data['isFavorite'] == true;
      final currentCompare = data['forComparison'] == true;
      final newCompare = !currentCompare;

      if (newCompare) {
        await _freeComparisonSlotIfNeeded(excludingPropertyId: propertyId);
      }

      if (!newCompare && !currentFav) {
        await docRef.delete();
      } else {
        await docRef.set({
          'userId': _uid,
          'propertyId': propertyId,
          'isFavorite': currentFav,
          'forComparison': newCompare,
          'createdAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      return newCompare ? ComparisonToggleResult.added : ComparisonToggleResult.removed;
    }

    await _freeComparisonSlotIfNeeded(excludingPropertyId: propertyId);

    await docRef.set({
      'userId': _uid,
      'propertyId': propertyId,
      'isFavorite': false,
      'forComparison': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return ComparisonToggleResult.added;
  }

  Future<void> _freeComparisonSlotIfNeeded({required String excludingPropertyId}) async {
    final snapshot = await _saved.where('userId', isEqualTo: _uid).get();
    final comparedDocs = snapshot.docs
        .where((doc) {
          final data = doc.data();
          return data['forComparison'] == true && (data['propertyId']?.toString() ?? '') != excludingPropertyId;
        })
        .toList()
      ..sort((a, b) => _timestampFromDoc(a).compareTo(_timestampFromDoc(b)));

    if (comparedDocs.length < maxComparisonCount) {
      return;
    }

    final oldest = comparedDocs.first;
    final data = oldest.data();
    final isFavorite = data['isFavorite'] == true;

    if (isFavorite) {
      await oldest.reference.set({
        'forComparison': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      await oldest.reference.delete();
    }
  }

  int _timestampFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final updatedAt = data['updatedAt'];
    if (updatedAt is Timestamp) return updatedAt.millisecondsSinceEpoch;
    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) return createdAt.millisecondsSinceEpoch;
    return 0;
  }

  Stream<List<String>> comparisonIds() {
    return _saved.where('userId', isEqualTo: _uid).snapshots().map((snapshot) {
      final sorted = snapshot.docs
          .where((doc) => doc.data()['forComparison'] == true)
          .toList()
        ..sort((a, b) => _timestampFromDoc(b).compareTo(_timestampFromDoc(a)));

      return sorted
          .map((d) => (d.data()['propertyId'] ?? '').toString())
          .where((e) => e.isNotEmpty)
          .take(maxComparisonCount)
          .toList();
    });
  }

  Stream<bool> isFavorite(String propertyId) {
    return _saved.doc(_docId(propertyId)).snapshots().map((doc) {
      if (!doc.exists) return false;
      return (doc.data()?['isFavorite'] ?? false) == true;
    });
  }

  Stream<bool> isInComparison(String propertyId) {
    return _saved.doc(_docId(propertyId)).snapshots().map((doc) {
      if (!doc.exists) return false;
      return (doc.data()?['forComparison'] ?? false) == true;
    });
  }
}
