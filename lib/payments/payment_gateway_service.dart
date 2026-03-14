import 'dart:math';

/// Gateway-agnostic payment states.
enum PaymentState { success, failed, pending }

class PaymentResult {
  final PaymentState state;
  final String transactionId;
  final String provider;
  final int amount;
  final String? failureReason;

  const PaymentResult({
    required this.state,
    required this.transactionId,
    required this.provider,
    required this.amount,
    this.failureReason,
  });

  bool get isSuccess => state == PaymentState.success;
}

/// Phase-1 provider abstraction.
/// Replace internals with Razorpay/Stripe SDK + backend verification.
class PaymentGatewayService {
  final Random _random = Random();

  Future<PaymentResult> payTokenAmount({
    required int amount,
    String provider = 'mock_gateway',
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final roll = _random.nextInt(100);
    final txId = 'TXN_${DateTime.now().millisecondsSinceEpoch}';

    if (roll < 85) {
      return PaymentResult(
        state: PaymentState.success,
        transactionId: txId,
        provider: provider,
        amount: amount,
      );
    }

    return PaymentResult(
      state: PaymentState.failed,
      transactionId: txId,
      provider: provider,
      amount: amount,
      failureReason: 'Payment authorization failed',
    );
  }

  Future<PaymentState> verifyTransaction(String transactionId) async {
    await Future.delayed(const Duration(milliseconds: 400));

    // Phase-1 mocked verification.
    final roll = _random.nextInt(100);
    if (roll < 80) return PaymentState.success;
    if (roll < 90) return PaymentState.pending;
    return PaymentState.failed;
  }
}
