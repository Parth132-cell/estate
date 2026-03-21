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
        final count = await _comparisonCount();
        if (count >= maxComparisonCount) {
          return ComparisonToggleResult.limitReached;
        }
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

    final count = await _comparisonCount();
    if (count >= maxComparisonCount) {
      return ComparisonToggleResult.limitReached;
    }

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

  Future<int> _comparisonCount() async {
    final snapshot = await _saved.where('userId', isEqualTo: _uid).get();
    return snapshot.docs.where((doc) => doc.data()['forComparison'] == true).length;
  }

  Stream<List<String>> comparisonIds() {
    return _saved.where('userId', isEqualTo: _uid).snapshots().map(
      (snapshot) => snapshot.docs
          .where((doc) => doc.data()['forComparison'] == true)
          .map((d) => (d.data()['propertyId'] ?? '').toString())
          .where((e) => e.isNotEmpty)
          .toList(),
    );
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
