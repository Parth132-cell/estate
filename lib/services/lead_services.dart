import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LeadService {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  /// Create Lead
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

  /// Broker Leads Stream
  Stream<QuerySnapshot> brokerLeads(String brokerId) {
    return _db
        .collection('leads')
        .where('brokerId', isEqualTo: brokerId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Buyer Leads
  Stream<QuerySnapshot> buyerLeads() {
    return _db
        .collection('leads')
        .where('buyerId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Update Lead Status (Broker)
  Future<void> updateStatus(String leadId, String status) async {
    await _db.collection('leads').doc(leadId).update({'status': status});
  }

  Future<void> updatePriority(String leadId, String priority) async {
    await _db.collection('leads').doc(leadId).update({'priority': priority});
  }

  Future<void> markContacted(String leadId) async {
    await _db.collection('leads').doc(leadId).update({
      'status': 'contacted',
      'lastContancted': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setFollowUp(String leadId, DateTime date) async {
    await _db.collection('leads').doc(leadId).update({
      'nextFollowUp': Timestamp.fromDate(date),
    });
  }
}
