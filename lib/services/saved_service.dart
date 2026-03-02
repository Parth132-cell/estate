import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SavedService {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  CollectionReference get _saved => _db.collection('saved');

  String _docId(String propertyId) => '${_uid}_$propertyId';

  /// Toggle Favorite
  Future<void> toggleFavorite(String propertyId) async {
    final docRef = _saved.doc(_docId(propertyId));
    final doc = await docRef.get();

    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;

      final currentFav = data['isFavorite'] ?? false;
      final currentCompare = data['forComparison'] ?? false;

      final newFav = !currentFav;

      // If both false → delete document
      if (!newFav && !currentCompare) {
        await docRef.delete();
      } else {
        await docRef.set({
          'userId': _uid,
          'propertyId': propertyId,
          'isFavorite': newFav,
          'forComparison': currentCompare,
          'createdAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } else {
      await docRef.set({
        'userId': _uid,
        'propertyId': propertyId,
        'isFavorite': true,
        'forComparison': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Toggle Comparison
  Future<void> toggleComparison(String propertyId) async {
    final docRef = _saved.doc(_docId(propertyId));
    final doc = await docRef.get();

    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;

      final currentFav = data['isFavorite'] ?? false;
      final currentCompare = data['forComparison'] ?? false;

      final newCompare = !currentCompare;

      // If both false → delete document
      if (!newCompare && !currentFav) {
        await docRef.delete();
      } else {
        await docRef.set({
          'userId': _uid,
          'propertyId': propertyId,
          'isFavorite': currentFav,
          'forComparison': newCompare,
          'createdAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } else {
      await docRef.set({
        'userId': _uid,
        'propertyId': propertyId,
        'isFavorite': false,
        'forComparison': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Stream favorites ONLY
  Stream<QuerySnapshot> favoritesStream() {
    return _saved
        .where('userId', isEqualTo: _uid)
        .where('isFavorite', isEqualTo: true)
        .snapshots();
  }

  /// Stream comparison IDs
  Stream<List<String>> comparisonIds() {
    return _saved
        .where('userId', isEqualTo: _uid)
        .where('forComparison', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((d) => d['propertyId'] as String).toList(),
        );
  }

  /// Check favorite status
  Stream<bool> isFavorite(String propertyId) {
    return _saved.doc(_docId(propertyId)).snapshots().map((doc) {
      if (!doc.exists) return false;
      return (doc.data() as Map<String, dynamic>)['isFavorite'] ?? false;
    });
  }

  /// Check comparison status
  Stream<bool> isInComparison(String propertyId) {
    return _saved.doc(_docId(propertyId)).snapshots().map((doc) {
      if (!doc.exists) return false;
      return (doc.data() as Map<String, dynamic>)['forComparison'] ?? false;
    });
  }
}
