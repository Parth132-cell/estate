import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DealServices {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

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

  Stream<QuerySnapshot> buyerDeals() {
    return _db
        .collection('deals')
        .where('buyerId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> brokerDeals() {
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
