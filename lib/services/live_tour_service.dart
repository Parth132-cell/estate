import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LiveTourService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');
    return user.uid;
  }

  Future<void> createTour({
    required String propertyId,
    required DateTime scheduleAt,
    String notes = '',
  }) async {
    await _db.collection('live_tours').add({
      'propertyId': propertyId,
      'hostId': _uid,
      'participantIds': <String>[],
      'status': 'scheduled',
      'notes': notes,
      'scheduledAt': Timestamp.fromDate(scheduleAt),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> hostedTours() {
    return _db
        .collection('live_tours')
        .where('hostId', isEqualTo: _uid)
        .orderBy('scheduledAt', descending: false)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> joinedTours() {
    return _db
        .collection('live_tours')
        .where('participantIds', arrayContains: _uid)
        .orderBy('scheduledAt', descending: false)
        .snapshots();
  }

  Future<void> joinTour(String tourId) async {
    await _db.collection('live_tours').doc(tourId).update({
      'participantIds': FieldValue.arrayUnion([_uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateStatus({
    required String tourId,
    required String status,
  }) async {
    await _db.collection('live_tours').doc(tourId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
