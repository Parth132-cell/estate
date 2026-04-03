import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'agreement_backend_service.dart';

class AgreementService {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final AgreementBackendService? _backendService;

  AgreementService({
    FirebaseFirestore? db,
    FirebaseStorage? storage,
    AgreementBackendService? backendService,
  }) : _db = db ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _backendService = backendService;

  /// Create agreement between buyer and seller.
  Future<String> createAgreement({
    required String dealId,
    required String buyerId,
    required String sellerId,
  }) async {
    final ref = await _db.collection('agreements').add({
      'dealId': dealId,
      'buyerId': buyerId,
      'sellerId': sellerId,
      'status': 'draft',
      'documentBody': _buildAgreementBody(
        dealId: dealId,
        buyerId: buyerId,
        sellerId: sellerId,
      ),
      'esignStatus': 'not_sent',
      'pdfUrl': null,
      'signatureRequestId': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  String _buildAgreementBody({
    required String dealId,
    required String buyerId,
    required String sellerId,
  }) {
    return '''
ESTATEX PURCHASE AGREEMENT

Deal ID: $dealId
Buyer ID: $buyerId
Seller ID: $sellerId

Terms:
1. Buyer and seller agree to proceed under EstateX escrow workflow.
2. Escrow release confirms commercial intent and transaction progression.
3. Agreement may be accepted or rejected by parties before closure.
4. Final legal completion requires digital signatures from buyer and seller.
''';
  }

  /// Accept agreement.
  Future<void> accept(String agreementId) async {
    await _db.collection('agreements').doc(agreementId).update({
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reject agreement.
  Future<void> reject(String agreementId, {String? reason}) async {
    await _db.collection('agreements').doc(agreementId).update({
      'status': 'rejected',
      'rejectionReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Render PDF via backend (if configured), then upload to Firebase Storage.
  Future<String> generatePdfAndUpload(String agreementId) async {
    final snap = await getById(agreementId);
    final agreement = snap.data();
    if (agreement == null) {
      throw Exception('Agreement not found');
    }

    final pdfBytes = await _resolvePdfBytes(agreementId: agreementId, data: agreement);

    final ref = _storage.ref('agreements/$agreementId/agreement.pdf');
    await ref.putData(
      pdfBytes,
      SettableMetadata(contentType: 'application/pdf'),
    );
    final pdfUrl = await ref.getDownloadURL();

    await _db.collection('agreements').doc(agreementId).update({
      'pdfUrl': pdfUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return pdfUrl;
  }

  Future<void> sendForEsign(String agreementId) async {
    final doc = await getById(agreementId);
    final data = doc.data() ?? <String, dynamic>{};
    final pdfUrl = data['pdfUrl']?.toString();
    if (pdfUrl == null || pdfUrl.isEmpty) {
      throw Exception('Generate PDF before sending for signature');
    }

    String? requestId;
    if (_backendService != null) {
      requestId = await _backendService.requestDigitalSignature(
        agreementId: agreementId,
        signerUserId: (data['buyerId'] ?? '').toString(),
        signerRole: 'buyer',
        pdfUrl: pdfUrl,
      );
    }

    await _db.collection('agreements').doc(agreementId).update({
      'esignStatus': 'pending_buyer',
      if (requestId != null) 'signatureRequestId': requestId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markBuyerSigned(String agreementId) async {
    await _db.collection('agreements').doc(agreementId).update({
      'esignStatus': 'pending_seller',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markSellerSigned(String agreementId) async {
    await _db.collection('agreements').doc(agreementId).update({
      'esignStatus': 'completed',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getById(String agreementId) {
    return _db.collection('agreements').doc(agreementId).get();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> forDeal(String dealId) {
    return _db
        .collection('agreements')
        .where('dealId', isEqualTo: dealId)
        .snapshots();
  }

  Future<Uint8List> _resolvePdfBytes({
    required String agreementId,
    required Map<String, dynamic> data,
  }) async {
    if (_backendService != null) {
      final response = await _backendService.renderAgreementPdf(
        agreementId: agreementId,
        dealId: (data['dealId'] ?? '').toString(),
        buyerId: (data['buyerId'] ?? '').toString(),
        sellerId: (data['sellerId'] ?? data['brokerId'] ?? '').toString(),
        body: (data['documentBody'] ?? '').toString(),
      );
      return response.pdfBytes;
    }

    // Minimal placeholder PDF bytes fallback for non-production envs.
    // This keeps integration paths testable before backend rollout.
    return Uint8List.fromList(
      'Agreement $agreementId\n${data['documentBody'] ?? ''}'.codeUnits,
    );
  }
}
