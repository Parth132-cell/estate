import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  final _db = FirebaseFirestore.instance;

  /// Pending brokers
  Stream<QuerySnapshot> pendingBrokers() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'broker')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<void> approveBroker(String uid) async {
    await _db.collection('users').doc(uid).update({'status': 'approved'});
  }

  /// Pending properties
  Stream<QuerySnapshot> pendingProperties() {
    return _db
        .collection('properties')
        .where('verified', isEqualTo: false)
        .snapshots();
  }

  Future<void> verifyProperty(String propertyId) async {
    await _db.collection('properties').doc(propertyId).update({
      'verified': true,
    });
  }
}
