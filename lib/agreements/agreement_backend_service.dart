import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class AgreementBackendResult {
  final Uint8List pdfBytes;
  final String? signatureRequestId;

  const AgreementBackendResult({
    required this.pdfBytes,
    this.signatureRequestId,
  });
}

/// Thin integration layer for production backend agreement APIs.
///
/// Expected endpoints:
/// POST {baseUrl}/agreements/render
/// POST {baseUrl}/agreements/signatures/request
class AgreementBackendService {
  final String baseUrl;
  final http.Client _httpClient;

  AgreementBackendService({
    required this.baseUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  Future<AgreementBackendResult> renderAgreementPdf({
    required String agreementId,
    required String dealId,
    required String buyerId,
    required String sellerId,
    required String body,
  }) async {
    final url = Uri.parse('$baseUrl/agreements/render');

    final response = await _httpClient.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'agreementId': agreementId,
        'dealId': dealId,
        'buyerId': buyerId,
        'sellerId': sellerId,
        'body': body,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to render agreement PDF (${response.statusCode})');
    }

    final map = jsonDecode(response.body) as Map<String, dynamic>;
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
    required String signerUserId,
    required String signerRole,
    required String pdfUrl,
  }) async {
    final url = Uri.parse('$baseUrl/agreements/signatures/request');

    final response = await _httpClient.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'agreementId': agreementId,
        'signerUserId': signerUserId,
        'signerRole': signerRole,
        'pdfUrl': pdfUrl,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to request digital signature (${response.statusCode})');
    }

    final map = jsonDecode(response.body) as Map<String, dynamic>;
    final requestId = (map['signatureRequestId'] ?? '').toString();
    if (requestId.isEmpty) {
      throw Exception('Backend response missing signatureRequestId');
    }
    return requestId;
  }
}
