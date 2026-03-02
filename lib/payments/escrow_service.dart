import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EscrowService {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  /// Create Escrow (Buyer pays token)
  Future<void> createEscrow({
    required String dealId,
    required String propertyId,
    required String brokerId,
    required int amount,
  }) async {
    await _db.collection('escrow').add({
      'dealId': dealId,
      'propertyId': propertyId,
      'buyerId': _uid,
      'brokerId': brokerId,
      'amount': amount,
      'status': 'held',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Buyer Escrow
  Stream<QuerySnapshot> buyerEscrow() {
    return _db
        .collection('escrow')
        .where('buyerId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Broker Escrow
  Stream<QuerySnapshot> brokerEscrow() {
    return _db
        .collection('escrow')
        .where('brokerId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Release Payment
  Future<void> release(String escrowId) async {
    await _db.collection('escrow').doc(escrowId).update({
      'status': 'released',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Refund Payment
  Future<void> refund(String escrowId) async {
    await _db.collection('escrow').doc(escrowId).update({
      'status': 'refunded',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
