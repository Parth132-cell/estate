import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ComparisonService {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  CollectionReference get _saved => _db.collection('saved');

  /// Stream list of comparison property IDs
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

  /// Add or remove property from comparison
  Future<void> toggleComparison(String propertyId) async {
    final query = await _saved
        .where('userId', isEqualTo: _uid)
        .where('propertyId', isEqualTo: propertyId)
        .get();

    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      final current = doc['forComparison'] ?? false;

      if (current) {
        await doc.reference.update({'forComparison': false});
      } else {
        await doc.reference.update({'forComparison': true});
      }
    } else {
      await _saved.add({
        'userId': _uid,
        'propertyId': propertyId,
        'forComparison': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
