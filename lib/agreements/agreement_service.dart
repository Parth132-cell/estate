import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'agreement_backend_service.dart';

class AgreementService {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final AgreementBackendService _backendService;
  final FirebaseAuth _auth;

  AgreementService({
    FirebaseFirestore? db,
    FirebaseStorage? storage,
    AgreementBackendService? backendService,
    FirebaseAuth? auth,
  }) : _db = db ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _backendService = backendService ?? AgreementBackendService(),
       _auth = auth ?? FirebaseAuth.instance;

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
      'esignProvider': 'docusign',
      'envelopeStatus': null,
      'envelopeId': null,
      'pdfUrl': null,
      'signedPdfUrl': null,
      'signedPdfPath': null,
      'signatureRequestId': null,
      'signers': {
        'buyer': {
          'userId': buyerId,
          'status': 'created',
        },
        'seller': {
          'userId': sellerId,
          'status': 'created',
        },
      },
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

    final requestId = await _backendService.requestDigitalSignature(
      agreementId: agreementId,
      pdfUrl: pdfUrl,
    );

    await _db.collection('agreements').doc(agreementId).update({
      'esignStatus': 'pending_buyer',
      'envelopeStatus': 'sent',
      if (requestId != null) 'signatureRequestId': requestId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> createSigningSession(String agreementId) {
    return _backendService.createSigningSession(
      agreementId: agreementId,
    );
  }

  Future<void> syncSignatureStatus(String agreementId) {
    return _backendService.syncSignatureStatus(agreementId);
  }

  String? currentSignerRole(Map<String, dynamic> data) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    if ((data['buyerId'] ?? '').toString() == uid) {
      return 'buyer';
    }
    if ((data['sellerId'] ?? data['brokerId'] ?? '').toString() == uid) {
      return 'seller';
    }
    return null;
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
    final signers = Map<String, dynamic>.from(data['signers'] as Map? ?? {});
    final buyerSigner =
        Map<String, dynamic>.from(signers['buyer'] as Map? ?? {});
    final sellerSigner =
        Map<String, dynamic>.from(signers['seller'] as Map? ?? {});
    try {
      final response = await _backendService.renderAgreementPdf(
        agreementId: agreementId,
        dealId: (data['dealId'] ?? '').toString(),
        buyerId: (data['buyerId'] ?? '').toString(),
        sellerId: (data['sellerId'] ?? data['brokerId'] ?? '').toString(),
        buyerName: (buyerSigner['name'] ?? '').toString(),
        sellerName: (sellerSigner['name'] ?? '').toString(),
        propertyTitle: data['propertyTitle']?.toString(),
        amount: (data['amount'] as num?)?.toInt(),
        body: (data['documentBody'] ?? '').toString(),
      );
      return response.pdfBytes;
    } catch (_) {
      return Uint8List.fromList(
        'Agreement $agreementId\n${data['documentBody'] ?? ''}'.codeUnits,
      );
    }
  }
}
