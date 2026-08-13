import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'payment_models.dart';

sealed class RazorpayCheckoutResult {
  const RazorpayCheckoutResult();
}

class RazorpayCheckoutSuccess extends RazorpayCheckoutResult {
  const RazorpayCheckoutSuccess({
    required this.orderId,
    required this.paymentId,
    required this.signature,
  });

  final String orderId;
  final String paymentId;
  final String signature;
}

class RazorpayCheckoutFailure extends RazorpayCheckoutResult {
  const RazorpayCheckoutFailure({
    required this.code,
    required this.description,
    this.step,
    this.source,
    this.reason,
  });

  final int code;
  final String description;
  final String? step;
  final String? source;
  final String? reason;
}

class RazorpayCheckoutService {
  Future<RazorpayCheckoutResult> openCheckout({
    required RazorpayOrderSession session,
    required String buyerName,
    required String buyerContact,
    required String buyerEmail,
  }) async {
    final razorpay = Razorpay();
    final completer = Completer<RazorpayCheckoutResult>();

    void complete(RazorpayCheckoutResult result) {
      if (!completer.isCompleted) {
        completer.complete(result);
      }
    }

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (dynamic response) {
      final success = response as PaymentSuccessResponse;
      complete(
        RazorpayCheckoutSuccess(
          orderId: success.orderId ?? session.orderId,
          paymentId: success.paymentId ?? '',
          signature: success.signature ?? '',
        ),
      );
    });

    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (dynamic response) {
      final failure = response as PaymentFailureResponse;
      complete(
        RazorpayCheckoutFailure(
          code: failure.code ?? -1,
          description: failure.message ?? 'Payment failed',
        ),
      );
    });

    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (dynamic response) {
      final wallet = response as ExternalWalletResponse;
      complete(
        RazorpayCheckoutFailure(
          code: -2,
          description: 'External wallet selected: ${wallet.walletName ?? 'wallet'}',
          source: 'external_wallet',
        ),
      );
    });

    try {
      razorpay.open({
        'key': session.keyId,
        'amount': session.amount,
        'currency': session.currency,
        'name': session.name,
        'description': session.description,
        'order_id': session.orderId,
        'prefill': {
          'name': buyerName,
          'contact': buyerContact,
          'email': buyerEmail,
        },
        'notes': {
          'paymentRecordId': session.paymentId,
        },
        'retry': {
          'enabled': true,
          'max_count': 1,
        },
      });

      return await completer.future;
    } finally {
      razorpay.clear();
    }
  }
}
