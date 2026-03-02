import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoriteService {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  CollectionReference get _saved => _db.collection('saved');

  /// Check if property is saved
  Stream<bool> isSaved(String propertyId) {
    return _saved
        .where('userId', isEqualTo: _uid)
        .where('propertyId', isEqualTo: propertyId)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  /// Toggle save / unsave
  Future<void> toggleFavorite(String propertyId) async {
    final query = await _saved
        .where('userId', isEqualTo: _uid)
        .where('propertyId', isEqualTo: propertyId)
        .get();

    if (query.docs.isNotEmpty) {
      // remove
      for (var doc in query.docs) {
        await doc.reference.delete();
      }
    } else {
      // add
      await _saved.add({
        'userId': _uid,
        'propertyId': propertyId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
