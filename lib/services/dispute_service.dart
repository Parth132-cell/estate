import 'package:cloud_firestore/cloud_firestore.dart';

class DisputeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> disputes() {
    return _db
        .collection('disputes')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> openDispute({
    required String dealId,
    required String raisedBy,
    required String reason,
  }) async {
    await _db.collection('disputes').add({
      'dealId': dealId,
      'raisedBy': raisedBy,
      'reason': reason,
      'status': 'open',
      'resolution': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> resolve({
    required String disputeId,
    required String resolution,
  }) async {
    await _db.collection('disputes').doc(disputeId).update({
      'status': 'resolved',
      'resolution': resolution,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
