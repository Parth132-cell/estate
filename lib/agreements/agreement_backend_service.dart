import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class AgreementBackendResult {
  final Uint8List pdfBytes;
  final String? signatureRequestId;

  const AgreementBackendResult({
    required this.pdfBytes,
    this.signatureRequestId,
  });
}

class AgreementBackendService {
  final String baseUrl;
  final FirebaseAuth _auth;
  final http.Client _httpClient;

  AgreementBackendService({
    String? baseUrl,
    FirebaseAuth? auth,
    http.Client? httpClient,
  }) : baseUrl = (baseUrl ?? const String.fromEnvironment('AGREEMENTS_API_BASE_URL')).trim(),
       _auth = auth ?? FirebaseAuth.instance,
       _httpClient = httpClient ?? http.Client();

  void _ensureConfigured() {
    if (baseUrl.isEmpty) {
      throw Exception(
        'Missing AGREEMENTS_API_BASE_URL. Pass it with --dart-define=AGREEMENTS_API_BASE_URL=https://<region>-<project>.cloudfunctions.net/paymentApi',
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
    final body = response.body.trim();
    if (body.isEmpty) {
      return <String, dynamic>{};
    }
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'data': decoded};
  }

  Future<AgreementBackendResult> renderAgreementPdf({
    required String agreementId,
    required String dealId,
    required String buyerId,
    required String sellerId,
    String? buyerName,
    String? sellerName,
    String? propertyTitle,
    int? amount,
    required String body,
  }) async {
    _ensureConfigured();
    final url = Uri.parse('$baseUrl/agreements/render');

    final response = await _httpClient.post(
      url,
      headers: await _headers(),
      body: jsonEncode({
        'agreementId': agreementId,
        'dealId': dealId,
        'buyerId': buyerId,
        'sellerId': sellerId,
        'buyerName': buyerName,
        'sellerName': sellerName,
        'propertyTitle': propertyTitle,
        'amount': amount,
        'body': body,
      }),
    );

    final map = await _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        (map['error'] ?? 'Failed to render agreement PDF (${response.statusCode})').toString(),
      );
    }

    final base64Pdf = (map['pdfBase64'] ?? '').toString();
    if (base64Pdf.isEmpty) {
      throw Exception('Backend response missing pdfBase64 payload');
    }

    return AgreementBackendResult(
      pdfBytes: base64Decode(base64Pdf),
      signatureRequestId: map['signatureRequestId']?.toString(),
    );
  }

  Future<String> requestDigitalSignature({
    required String agreementId,
    required String pdfUrl,
  }) async {
    _ensureConfigured();
    final url = Uri.parse('$baseUrl/agreements/signatures/request');

    final response = await _httpClient.post(
      url,
      headers: await _headers(),
      body: jsonEncode({
        'agreementId': agreementId,
        'pdfUrl': pdfUrl,
      }),
    );

    final map = await _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        (map['error'] ?? 'Failed to request digital signature (${response.statusCode})').toString(),
      );
    }

    final requestId = (map['signatureRequestId'] ?? '').toString();
    if (requestId.isEmpty) {
      throw Exception('Backend response missing signatureRequestId');
    }
    return requestId;
  }

  Future<String> createSigningSession({
    required String agreementId,
    String? returnUrl,
  }) async {
    _ensureConfigured();
    final url = Uri.parse('$baseUrl/agreements/$agreementId/signing-session');
    final response = await _httpClient.post(
      url,
      headers: await _headers(),
      body: jsonEncode({
        if (returnUrl != null && returnUrl.trim().isNotEmpty)
          'returnUrl': returnUrl.trim(),
      }),
    );

    final map = await _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        (map['error'] ?? 'Failed to create signing session (${response.statusCode})').toString(),
      );
    }

    final signingUrl = (map['url'] ?? '').toString();
    if (signingUrl.isEmpty) {
      throw Exception('Backend response missing signing URL');
    }
    return signingUrl;
  }

  Future<void> syncSignatureStatus(String agreementId) async {
    _ensureConfigured();
    final url = Uri.parse('$baseUrl/agreements/$agreementId/sync-signature-status');
    final response = await _httpClient.post(
      url,
      headers: await _headers(),
      body: '{}',
    );

    final map = await _decodeResponse(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        (map['error'] ?? 'Failed to sync agreement status (${response.statusCode})').toString(),
      );
    }
  }
}
