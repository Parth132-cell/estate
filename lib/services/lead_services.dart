import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LeadService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const List<String> statuses = ['new', 'contacted', 'closed'];
  static const List<String> priorities = ['low', 'medium', 'high'];

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
      'name': 'Unknown',
      'phone': '',
      'message': message,
      'status': 'new',
      'priority': 'medium',
      'followUpDate': null,
      'lastContacted': null,
      'notes': <Map<String, dynamic>>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createManualLead({
    required String brokerId,
    required String name,
    required String phone,
    required String priority,
    DateTime? followUpDate,
  }) async {
    await _db.collection('leads').add({
      'propertyId': null,
      'brokerId': brokerId,
      'buyerId': _uid,
      'name': name.trim(),
      'phone': phone.trim(),
      'status': 'new',
      'priority': priority,
      'followUpDate':
          followUpDate == null ? null : Timestamp.fromDate(followUpDate),
      'lastContacted': null,
      'notes': <Map<String, dynamic>>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> brokerLeads(String brokerId) {
    return _db
        .collection('leads')
        .where('brokerId', isEqualTo: brokerId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> brokerLeadsByStatus({
    required String brokerId,
    required String status,
  }) {
    return _db
        .collection('leads')
        .where('brokerId', isEqualTo: brokerId)
        .where('status', isEqualTo: status)
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
    await _db.collection('leads').doc(leadId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      if (status == 'contacted')
        'lastContacted': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updatePriority(String leadId, String priority) async {
    await _db.collection('leads').doc(leadId).update({
      'priority': priority,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markContacted(String leadId) async {
    await _db.collection('leads').doc(leadId).update({
      'status': 'contacted',
      'lastContacted': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setFollowUp(String leadId, DateTime date) async {
    await _db.collection('leads').doc(leadId).update({
      'followUpDate': Timestamp.fromDate(date),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addNote({
    required String leadId,
    required String note,
  }) async {
    if (note.trim().isEmpty) return;

    await _db.collection('leads').doc(leadId).update({
      'notes': FieldValue.arrayUnion([
        {
          'text': note.trim(),
          'createdAt': Timestamp.now(),
          'createdBy': _uid,
        }
      ]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
