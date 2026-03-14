import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ComparisonService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _saved => _db.collection('saved');

  Stream<List<String>> comparisonIds() {
    return _saved
        .where('userId', isEqualTo: _uid)
        .where('forComparison', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => (d.data()['propertyId'] ?? '').toString()).where((e) => e.isNotEmpty).toList());
  }

  Future<void> toggleComparison(String propertyId) async {
    final docRef = _saved.doc('${_uid}_$propertyId');
    final doc = await docRef.get();

    if (doc.exists) {
      final data = doc.data() ?? <String, dynamic>{};
      final current = data['forComparison'] == true;
      final favorite = data['isFavorite'] == true;
      final newValue = !current;

      if (!newValue && !favorite) {
        await docRef.delete();
      } else {
        await docRef.set({
          'userId': _uid,
          'propertyId': propertyId,
          'forComparison': newValue,
          'isFavorite': favorite,
          'createdAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      return;
    }

    await docRef.set({
      'userId': _uid,
      'propertyId': propertyId,
      'forComparison': true,
      'isFavorite': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
