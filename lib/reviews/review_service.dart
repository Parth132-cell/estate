import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewService {
  final _db = FirebaseFirestore.instance;

  /// Add review (only once per deal)
  Future<void> addReview({
    required String dealId,
    required String propertyId,
    required String brokerId,
    required String reviewerId,
    required int rating,
    required String comment,
  }) async {
    await _db.collection('reviews').add({
      'dealId': dealId,
      'propertyId': propertyId,
      'brokerId': brokerId,
      'reviewerId': reviewerId,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reviews for broker
  Stream<QuerySnapshot<Map<String, dynamic>>> forBroker(String brokerId) {
    return _db
        .collection('reviews')
        .where('brokerId', isEqualTo: brokerId)
        .snapshots();
  }

  /// Reviews for property
  Stream<QuerySnapshot<Map<String, dynamic>>> forProperty(String propertyId) {
    return _db
        .collection('reviews')
        .where('propertyId', isEqualTo: propertyId)
        .snapshots();
  }
}
