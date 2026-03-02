import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'payment_gateway_service.dart';

class EscrowService {
  final _db = FirebaseFirestore.instance;
  final PaymentGatewayService _paymentGatewayService = PaymentGatewayService();

  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.uid;
  }

  /// Create Escrow after receiving a payment result.
  Future<String> createEscrow({
    required String dealId,
    required String propertyId,
    required String brokerId,
    required int amount,
    String paymentStatus = 'success',
    String? transactionId,
    String provider = 'mock_gateway',
  }) async {
    final docRef = await _db.collection('escrow').add({
      'dealId': dealId,
      'propertyId': propertyId,
      'buyerId': _uid,
      'brokerId': brokerId,
      'amount': amount,
      'status': paymentStatus == 'success' ? 'held' : 'payment_pending',
      'paymentStatus': paymentStatus,
      'provider': provider,
      'transactionId': transactionId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  /// Phase-1 token payment + escrow hold orchestration.
  Future<String> createEscrowWithPayment({
    required String dealId,
    required String propertyId,
    required String brokerId,
    required int amount,
  }) async {
    final result = await _paymentGatewayService.payTokenAmount(amount: amount);

    if (!result.isSuccess) {
      throw Exception(result.failureReason ?? 'Token payment failed');
    }

    return createEscrow(
      dealId: dealId,
      propertyId: propertyId,
      brokerId: brokerId,
      amount: amount,
      paymentStatus: 'success',
      transactionId: result.transactionId,
      provider: result.provider,
    );
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

  /// Reconcile payment-pending escrow records.
  Future<int> reconcilePendingEscrows() async {
    final snapshot = await _db
        .collection('escrow')
        .where('buyerId', isEqualTo: _uid)
        .where('paymentStatus', whereIn: ['pending', 'processing'])
        .get();

    int updated = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final transactionId = data['transactionId'] as String?;

      if (transactionId == null || transactionId.isEmpty) continue;

      final paymentState = await _paymentGatewayService.verifyTransaction(
        transactionId,
      );

      String paymentStatus;
      String escrowStatus;

      switch (paymentState) {
        case PaymentState.success:
          paymentStatus = 'success';
          escrowStatus = 'held';
          break;
        case PaymentState.pending:
          paymentStatus = 'pending';
          escrowStatus = 'payment_pending';
          break;
        case PaymentState.failed:
          paymentStatus = 'failed';
          escrowStatus = 'payment_failed';
          break;
      }

      await _db.collection('escrow').doc(doc.id).update({
        'paymentStatus': paymentStatus,
        'status': escrowStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      updated++;
    }

    return updated;
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
