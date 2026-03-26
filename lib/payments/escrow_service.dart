import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'escrow_model.dart';
import 'payment_gateway_service.dart';

class EscrowService {
  final _db = FirebaseFirestore.instance;
  final PaymentGatewayService _paymentGatewayService = PaymentGatewayService();

  static const Map<String, Set<String>> _allowedTransitions = {
    EscrowState.initiated: {EscrowState.paymentPending, EscrowState.cancelled},
    EscrowState.paymentPending: {EscrowState.completed, EscrowState.cancelled},
    EscrowState.completed: {},
    EscrowState.cancelled: {},
  };

  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.uid;
  }

  Future<void> _writeAuditLog({
    required String escrowId,
    required String action,
    String? fromState,
    String? toState,
    Map<String, dynamic>? metadata,
  }) async {
    await _db.collection('escrow').doc(escrowId).collection('audit_logs').add({
      'action': action,
      'fromState': fromState,
      'toState': toState,
      'actorId': FirebaseAuth.instance.currentUser?.uid,
      'metadata': metadata ?? {},
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Create Escrow record in initiated state.
  Future<String> createEscrow({
    required String dealId,
    required String propertyId,
    required String brokerId,
    required int amount,
    String provider = PaymentProvider.stripe,
  }) async {
    if (!PaymentProvider.supported.contains(provider)) {
      throw ArgumentError('Unsupported payment provider: $provider');
    }

    final docRef = await _db.collection('escrow').add({
      'dealId': dealId,
      'propertyId': propertyId,
      'buyerId': _uid,
      'brokerId': brokerId,
      'amount': amount,
      'status': EscrowState.initiated,
      'paymentStatus': 'not_started',
      'provider': provider,
      'transactionId': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _writeAuditLog(
      escrowId: docRef.id,
      action: 'escrow_created',
      toState: EscrowState.initiated,
      metadata: {
        'dealId': dealId,
        'propertyId': propertyId,
        'amount': amount,
        'provider': provider,
      },
    );

    return docRef.id;
  }

  /// Performs payment via Stripe or Razorpay and advances escrow state.
  Future<String> createEscrowWithPayment({
    required String dealId,
    required String propertyId,
    required String brokerId,
    required int amount,
    String provider = PaymentProvider.stripe,
  }) async {
    final escrowId = await createEscrow(
      dealId: dealId,
      propertyId: propertyId,
      brokerId: brokerId,
      amount: amount,
      provider: provider,
    );

    final result = provider == PaymentProvider.razorpay
        ? await _paymentGatewayService.payWithRazorpay(amount: amount)
        : await _paymentGatewayService.payWithStripe(amount: amount);

    await _db.collection('escrow').doc(escrowId).update({
      'paymentStatus': result.state.name,
      'transactionId': result.transactionId,
      'provider': result.provider,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (result.state == PaymentState.failed) {
      await transitionState(
        escrowId: escrowId,
        nextState: EscrowState.cancelled,
        action: 'payment_failed',
        metadata: {
          'provider': result.provider,
          'failureReason': result.failureReason,
          'transactionId': result.transactionId,
        },
      );

      throw Exception(result.failureReason ?? 'Token payment failed');
    }

    await transitionState(
      escrowId: escrowId,
      nextState: EscrowState.paymentPending,
      action: 'payment_authorized',
      metadata: {
        'provider': result.provider,
        'transactionId': result.transactionId,
      },
    );

    return escrowId;
  }

  /// Controlled state transition with audit logging.
  Future<void> transitionState({
    required String escrowId,
    required String nextState,
    required String action,
    Map<String, dynamic>? metadata,
  }) async {
    if (!EscrowState.all.contains(nextState)) {
      throw Exception('Invalid escrow state: $nextState');
    }

    String previousState = EscrowState.initiated;

    await _db.runTransaction((trx) async {
      final docRef = _db.collection('escrow').doc(escrowId);
      final snapshot = await trx.get(docRef);

      if (!snapshot.exists) {
        throw Exception('Escrow not found: $escrowId');
      }

      final currentState =
          (snapshot.data()?['status'] ?? EscrowState.initiated).toString();
      previousState = currentState;

      if (currentState == nextState) {
        return;
      }

      final allowed = _allowedTransitions[currentState] ?? {};
      if (!allowed.contains(nextState)) {
        throw Exception('Invalid transition: $currentState -> $nextState');
      }

      trx.update(docRef, {
        'status': nextState,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    if (previousState != nextState) {
      await _writeAuditLog(
        escrowId: escrowId,
        action: action,
        fromState: previousState,
        toState: nextState,
        metadata: metadata,
      );
    }
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
        .where('status', isEqualTo: EscrowState.paymentPending)
        .get();

    int updated = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final transactionId = data['transactionId'] as String?;

      if (transactionId == null || transactionId.isEmpty) continue;

      final paymentState = await _paymentGatewayService.verifyTransaction(
        transactionId,
      );

      if (paymentState == PaymentState.success) {
        await transitionState(
          escrowId: doc.id,
          nextState: EscrowState.completed,
          action: 'payment_settled',
          metadata: {'transactionId': transactionId},
        );

        await _db.collection('escrow').doc(doc.id).update({
          'paymentStatus': 'success',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else if (paymentState == PaymentState.failed) {
        await transitionState(
          escrowId: doc.id,
          nextState: EscrowState.cancelled,
          action: 'payment_reversed',
          metadata: {'transactionId': transactionId},
        );

        await _db.collection('escrow').doc(doc.id).update({
          'paymentStatus': 'failed',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _db.collection('escrow').doc(doc.id).update({
          'paymentStatus': 'pending',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      updated++;
    }

    return updated;
  }

  /// Mark escrow as completed.
  Future<void> release(String escrowId) async {
    await transitionState(
      escrowId: escrowId,
      nextState: EscrowState.completed,
      action: 'escrow_completed',
    );
  }

  /// Cancel escrow and refund buyer.
  Future<void> refund(String escrowId) async {
    await transitionState(
      escrowId: escrowId,
      nextState: EscrowState.cancelled,
      action: 'escrow_cancelled',
    );
  }
}
