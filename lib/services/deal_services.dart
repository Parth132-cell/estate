import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DealServices {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.uid;
  }

  Future<void> createOffer({
    required String propertyId,
    required String brokerId,
    required int amount,
  }) async {
    await _db.collection('deals').add({
      'propertyId': propertyId,
      'brokerId': brokerId,
      'buyerId': _uid,
      'offerAmount': amount,
      'counterAmount': null,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> buyerDeals() {
    return _db
        .collection('deals')
        .where('buyerId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> brokerDeals() {
    return _db
        .collection('deals')
        .where('brokerId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> updateDealStatus(String dealId, String status) async {
    await _db.collection('deals').doc(dealId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> counterOffer({
    required String dealId,
    required int counterAmount,
  }) async {
    await _db.collection('deals').doc(dealId).update({
      'counterAmount': counterAmount,
      'status': 'counter',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
