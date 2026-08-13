import 'package:cloud_firestore/cloud_firestore.dart';

class DisputeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// All disputes, newest first (used in old screen — keep for compatibility).
  Stream<QuerySnapshot<Map<String, dynamic>>> disputes() {
    return _db
        .collection('disputes')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Disputes filtered by status — used by the new admin tabbed screen.
  Stream<QuerySnapshot<Map<String, dynamic>>> disputesByStatus(String status) {
    return _db
        .collection('disputes')
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> openDispute({
    required String dealId,
    required String raisedBy,
    required String reason,
    String? buyerId,
    String? sellerId,
  }) async {
    await _db.collection('disputes').add({
      'dealId': dealId,
      'raisedBy': raisedBy,
      'buyerId': buyerId,
      'sellerId': sellerId,
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

  /// Escalate for senior admin review.
  Future<void> escalate(String disputeId) async {
    await _db.collection('disputes').doc(disputeId).update({
      'status': 'escalated',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
