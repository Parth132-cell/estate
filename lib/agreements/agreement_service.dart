import 'package:cloud_firestore/cloud_firestore.dart';

class AgreementService {
  final _db = FirebaseFirestore.instance;

  /// Create agreement after escrow release
  Future<void> createAgreement({
    required String dealId,
    required String buyerId,
    required String brokerId,
  }) async {
    await _db.collection('agreements').add({
      'dealId': dealId,
      'buyerId': buyerId,
      'brokerId': brokerId,
      'status': 'draft',
      'documentBody': _buildAgreementBody(
        dealId: dealId,
        buyerId: buyerId,
        brokerId: brokerId,
      ),
      'esignStatus': 'not_sent',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  String _buildAgreementBody({
    required String dealId,
    required String buyerId,
    required String brokerId,
  }) {
    return '''
ESTATEX AGREEMENT (Phase-1 Template)

Deal ID: $dealId
Buyer ID: $buyerId
Broker ID: $brokerId

Terms:
1. Buyer and broker agree to proceed under EstateX escrow workflow.
2. Escrow release confirms commercial intent and deal progression.
3. Final legal instrument and eSign completion are required before closure.
''';
  }

  /// Accept agreement
  Future<void> accept(String agreementId) async {
    await _db.collection('agreements').doc(agreementId).update({
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendForEsign(String agreementId) async {
    await _db.collection('agreements').doc(agreementId).update({
      'esignStatus': 'sent',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markEsignCompleted(String agreementId) async {
    await _db.collection('agreements').doc(agreementId).update({
      'esignStatus': 'completed',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getById(String agreementId) {
    return _db.collection('agreements').doc(agreementId).get();
  }

  /// Fetch agreement for deal
  Stream<QuerySnapshot<Map<String, dynamic>>> forDeal(String dealId) {
    return _db
        .collection('agreements')
        .where('dealId', isEqualTo: dealId)
        .snapshots();
  }
}
