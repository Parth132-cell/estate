import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'payment_models.dart';

class RazorpayBackendService {
  RazorpayBackendService({
    String? baseUrl,
    FirebaseAuth? auth,
    http.Client? httpClient,
  }) : _baseUrl = (baseUrl ?? const String.fromEnvironment('PAYMENTS_API_BASE_URL')).trim(),
       _auth = auth ?? FirebaseAuth.instance,
       _httpClient = httpClient ?? http.Client();

  final String _baseUrl;
  final FirebaseAuth _auth;
  final http.Client _httpClient;

  void _ensureConfigured() {
    if (_baseUrl.isEmpty) {
      throw Exception(
        'Missing PAYMENTS_API_BASE_URL. Pass it with --dart-define=PAYMENTS_API_BASE_URL=https://<region>-<project>.cloudfunctions.net/paymentApi',
      );
    }
  }

  Future<Map<String, String>> _headers() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final token = await user.getIdToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, dynamic>> _decodeResponse(http.Response response) async {
    final raw = response.body.trim();
    if (raw.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'data': decoded};
  }

  Future<RazorpayOrderSession> createOrder({
    required String escrowId,
    required String dealId,
    required String propertyId,
    required String brokerId,
    required int amount,
    String currency = 'INR',
    String description = 'Token payment for secure property escrow',
  }) async {
    _ensureConfigured();

    final response = await _httpClient.post(
      Uri.parse('$_baseUrl/payments/razorpay/orders'),
      headers: await _headers(),
      body: jsonEncode({
        'escrowId': escrowId,
        'dealId': dealId,
        'propertyId': propertyId,
        'brokerId': brokerId,
        'amount': amount,
        'currency': currency,
        'description': description,
      }),
    );

    final body = await _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception((body['error'] ?? 'Failed to create Razorpay order').toString());
    }

    return RazorpayOrderSession.fromMap(body);
  }

  Future<PaymentVerificationResult> verifyPayment({
    required String paymentId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    _ensureConfigured();

    final response = await _httpClient.post(
      Uri.parse('$_baseUrl/payments/razorpay/verify'),
      headers: await _headers(),
      body: jsonEncode({
        'paymentId': paymentId,
        'razorpayOrderId': razorpayOrderId,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpaySignature': razorpaySignature,
      }),
    );

    final body = await _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception((body['error'] ?? 'Payment verification failed').toString());
    }

    final paymentStatus = (body['paymentStatus'] ?? 'pending').toString();
    final state = switch (paymentStatus) {
      'success' => PaymentState.success,
      'failed' => PaymentState.failed,
      _ => PaymentState.pending,
    };

    return PaymentVerificationResult(
      state: state,
      paymentId: (body['paymentId'] ?? paymentId).toString(),
      gatewayPaymentId: (body['razorpayPaymentId'] ?? razorpayPaymentId).toString(),
      status: (body['status'] ?? '').toString(),
      failureReason: body['error']?.toString(),
    );
  }

  Future<void> reportFailure({
    required String paymentId,
    required int code,
    required String description,
    String? step,
    String? source,
    String? reason,
  }) async {
    _ensureConfigured();

    final response = await _httpClient.post(
      Uri.parse('$_baseUrl/payments/razorpay/failure'),
      headers: await _headers(),
      body: jsonEncode({
        'paymentId': paymentId,
        'code': code,
        'description': description,
        'step': step,
        'source': source,
        'reason': reason,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await _decodeResponse(response);
      throw Exception((body['error'] ?? 'Failed to record payment failure').toString());
    }
  }
}
