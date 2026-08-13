enum PaymentState { success, failed, pending }

class PaymentResult {
  const PaymentResult({
    required this.state,
    required this.transactionId,
    required this.provider,
    required this.amount,
    this.orderId,
    this.paymentRecordId,
    this.failureReason,
  });

  final PaymentState state;
  final String transactionId;
  final String provider;
  final int amount;
  final String? orderId;
  final String? paymentRecordId;
  final String? failureReason;

  bool get isSuccess => state == PaymentState.success;
}

class PaymentProvider {
  static const String stripe = 'stripe';
  static const String razorpay = 'razorpay';

  static const Set<String> supported = {stripe, razorpay};
}

class RazorpayOrderSession {
  const RazorpayOrderSession({
    required this.paymentId,
    required this.orderId,
    required this.keyId,
    required this.amount,
    required this.currency,
    required this.name,
    required this.description,
  });

  final String paymentId;
  final String orderId;
  final String keyId;
  final int amount;
  final String currency;
  final String name;
  final String description;

  factory RazorpayOrderSession.fromMap(Map<String, dynamic> map) {
    return RazorpayOrderSession(
      paymentId: (map['paymentId'] ?? '').toString(),
      orderId: (map['orderId'] ?? '').toString(),
      keyId: (map['keyId'] ?? '').toString(),
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      currency: (map['currency'] ?? 'INR').toString(),
      name: (map['name'] ?? 'EstateX').toString(),
      description: (map['description'] ?? '').toString(),
    );
  }
}

class PaymentVerificationResult {
  const PaymentVerificationResult({
    required this.state,
    required this.paymentId,
    required this.gatewayPaymentId,
    required this.status,
    this.failureReason,
  });

  final PaymentState state;
  final String paymentId;
  final String gatewayPaymentId;
  final String status;
  final String? failureReason;
}
