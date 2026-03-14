import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoriteService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _saved => _db.collection('saved');

  Stream<bool> isSaved(String propertyId) {
    return _saved.doc('${_uid}_$propertyId').snapshots().map((doc) {
      if (!doc.exists) return false;
      return (doc.data()?['isFavorite'] ?? false) == true;
    });
  }

  Future<void> toggleFavorite(String propertyId) async {
    final docRef = _saved.doc('${_uid}_$propertyId');
    final doc = await docRef.get();

    if (doc.exists) {
      final data = doc.data() ?? <String, dynamic>{};
      final current = data['isFavorite'] == true;
      final compare = data['forComparison'] == true;
      final newFav = !current;

      if (!newFav && !compare) {
        await docRef.delete();
      } else {
        await docRef.set({
          'userId': _uid,
          'propertyId': propertyId,
          'isFavorite': newFav,
          'forComparison': compare,
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
}
