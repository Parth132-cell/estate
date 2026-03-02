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
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Accept agreement
  Future<void> accept(String agreementId) async {
    await _db.collection('agreements').doc(agreementId).update({
      'status': 'accepted',
    });
  }

  /// Fetch agreement for deal
  Stream<QuerySnapshot<Map<String, dynamic>>> forDeal(String dealId) {
    return _db
        .collection('agreements')
        .where('dealId', isEqualTo: dealId)
        .snapshots();
  }
}
