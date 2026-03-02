import 'package:cloud_firestore/cloud_firestore.dart';

class CoBrokerService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> assignCoBroker({
    required String dealId,
    required String coBrokerId,
    required int splitPercent,
  }) async {
    await _db.collection('deals').doc(dealId).update({
      'coBrokerId': coBrokerId,
      'coBrokerSplitPercent': splitPercent,
      'coBrokerStatus': 'invited',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> respondToInvite({
    required String dealId,
    required bool accepted,
  }) async {
    await _db.collection('deals').doc(dealId).update({
      'coBrokerStatus': accepted ? 'accepted' : 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
