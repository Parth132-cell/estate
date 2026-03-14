import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LeadService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.uid;
  }

  Future<void> createLead({
    required String propertyId,
    required String brokerId,
    String message = '',
  }) async {
    await _db.collection('leads').add({
      'propertyId': propertyId,
      'brokerId': brokerId,
      'buyerId': _uid,
      'message': message,
      'status': 'new',
      'priority': 'warm',
      'lastContacted': null,
      'nextFollowUp': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> brokerLeads(String brokerId) {
    return _db
        .collection('leads')
        .where('brokerId', isEqualTo: brokerId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> buyerLeads() {
    return _db
        .collection('leads')
        .where('buyerId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> updateStatus(String leadId, String status) async {
    await _db.collection('leads').doc(leadId).update({'status': status});
  }

  Future<void> updatePriority(String leadId, String priority) async {
    await _db.collection('leads').doc(leadId).update({'priority': priority});
  }

  Future<void> markContacted(String leadId) async {
    await _db.collection('leads').doc(leadId).update({
      'status': 'contacted',
      'lastContacted': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setFollowUp(String leadId, DateTime date) async {
    await _db.collection('leads').doc(leadId).update({
      'nextFollowUp': Timestamp.fromDate(date),
    });
  }
}
