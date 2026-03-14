import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VisitScheduleService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');
    return user.uid;
  }

  Future<void> scheduleVisit({
    required String propertyId,
    required String brokerId,
    required DateTime when,
    String note = '',
  }) async {
    await _db.collection('visit_requests').add({
      'propertyId': propertyId,
      'buyerId': _uid,
      'brokerId': brokerId,
      'status': 'requested',
      'scheduledAt': Timestamp.fromDate(when),
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> buyerVisits() {
    return _db
        .collection('visit_requests')
        .where('buyerId', isEqualTo: _uid)
        .orderBy('scheduledAt', descending: false)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> brokerVisits() {
    return _db
        .collection('visit_requests')
        .where('brokerId', isEqualTo: _uid)
        .orderBy('scheduledAt', descending: false)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> allVisits() {
    return _db
        .collection('visit_requests')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> updateStatus({required String requestId, required String status}) {
    const allowed = {'approved', 'completed', 'cancelled', 'requested'};
    if (!allowed.contains(status)) {
      throw Exception('Invalid visit status: $status');
    }

    return _db.collection('visit_requests').doc(requestId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
