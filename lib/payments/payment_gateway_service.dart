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

/// Supported payment providers.
class PaymentProvider {
  static const String stripe = 'stripe';
  static const String razorpay = 'razorpay';

  static const Set<String> supported = {stripe, razorpay};
}

/// Phase-1 provider abstraction.
/// Replace internals with Stripe/Razorpay SDK + backend verification.
class PaymentGatewayService {
  final Random _random = Random();

  Future<PaymentResult> payTokenAmount({
    required int amount,
    required String provider,
  }) async {
    if (!PaymentProvider.supported.contains(provider)) {
      throw ArgumentError('Unsupported payment provider: $provider');
    }

    await Future.delayed(const Duration(milliseconds: 800));

    final roll = _random.nextInt(100);
    final txId = '${provider.toUpperCase()}_${DateTime.now().millisecondsSinceEpoch}';

    if (roll < 80) {
      return PaymentResult(
        state: PaymentState.success,
        transactionId: txId,
        provider: provider,
        amount: amount,
      );
    }

    if (roll < 92) {
      return PaymentResult(
        state: PaymentState.pending,
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

  Future<PaymentResult> payWithStripe({required int amount}) {
    return payTokenAmount(amount: amount, provider: PaymentProvider.stripe);
  }

  Future<PaymentResult> payWithRazorpay({required int amount}) {
    return payTokenAmount(amount: amount, provider: PaymentProvider.razorpay);
  }

  Future<PaymentState> verifyTransaction(String transactionId) async {
    await Future.delayed(const Duration(milliseconds: 400));

    // Phase-1 mocked verification.
    final roll = _random.nextInt(100);
    if (roll < 78) return PaymentState.success;
    if (roll < 93) return PaymentState.pending;
    return PaymentState.failed;
  }
}
