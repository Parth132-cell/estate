import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'payment_models.dart';
import 'razorpay_backend_service.dart';
import 'razorpay_checkout_service.dart';

export 'payment_models.dart';

class PaymentGatewayService {
  PaymentGatewayService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    RazorpayBackendService? backendService,
    RazorpayCheckoutService? checkoutService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _db = firestore ?? FirebaseFirestore.instance,
       _backendService = backendService ?? RazorpayBackendService(),
       _checkoutService = checkoutService ?? RazorpayCheckoutService();

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final RazorpayBackendService _backendService;
  final RazorpayCheckoutService _checkoutService;

  Future<PaymentResult> payWithStripe({required int amount}) async {
    throw UnimplementedError('Stripe is not configured in this build.');
  }

  Future<PaymentResult> payWithRazorpay({
    required int amount,
    required String escrowId,
    required String dealId,
    required String propertyId,
    required String brokerId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final userSnap = await _db.collection('users').doc(user.uid).get();
    final userData = userSnap.data() ?? <String, dynamic>{};
    final buyerName = (userData['name'] ?? user.displayName ?? 'EstateX Buyer')
        .toString()
        .trim();
    final buyerContact = (userData['phone'] ?? user.phoneNumber ?? '').toString();
    final buyerEmail = (userData['email'] ?? user.email ?? '').toString();

    final order = await _backendService.createOrder(
      escrowId: escrowId,
      dealId: dealId,
      propertyId: propertyId,
      brokerId: brokerId,
      amount: amount,
    );

    final checkoutResult = await _checkoutService.openCheckout(
      session: order,
      buyerName: buyerName,
      buyerContact: buyerContact,
      buyerEmail: buyerEmail,
    );

    if (checkoutResult case RazorpayCheckoutSuccess success) {
      final verification = await _backendService.verifyPayment(
        paymentId: order.paymentId,
        razorpayOrderId: success.orderId,
        razorpayPaymentId: success.paymentId,
        razorpaySignature: success.signature,
      );

      return PaymentResult(
        state: verification.state,
        transactionId: verification.gatewayPaymentId,
        provider: PaymentProvider.razorpay,
        amount: amount,
        orderId: success.orderId,
        paymentRecordId: verification.paymentId,
        failureReason: verification.failureReason,
      );
    }

    final failure = checkoutResult as RazorpayCheckoutFailure;
    try {
      await _backendService.reportFailure(
        paymentId: order.paymentId,
        code: failure.code,
        description: failure.description,
        step: failure.step,
        source: failure.source,
        reason: failure.reason,
      );
    } catch (_) {
      // The backend failure log is best-effort. The checkout error is still surfaced.
    }

    return PaymentResult(
      state: PaymentState.failed,
      transactionId: order.orderId,
      provider: PaymentProvider.razorpay,
      amount: amount,
      orderId: order.orderId,
      paymentRecordId: order.paymentId,
      failureReason: failure.description,
    );
  }

  Future<PaymentState> verifyTransaction(String transactionId) async {
    final snapshot = await _db
        .collection('payments')
        .where('gateway.paymentId', isEqualTo: transactionId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return PaymentState.pending;
    }

    final data = snapshot.docs.first.data();
    return switch ((data['paymentStatus'] ?? 'pending').toString()) {
      'success' => PaymentState.success,
      'failed' => PaymentState.failed,
      _ => PaymentState.pending,
    };
  }
}
