import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Pending brokers
  Stream<QuerySnapshot<Map<String, dynamic>>> pendingBrokers() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'broker')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<void> approveBroker(String uid) async {
    await _db.collection('users').doc(uid).update({'status': 'approved'});
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> propertiesByStatus(String status) {
    return _db
        .collection('properties')
        .where('verificationStatus', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> approveProperty(String propertyId) {
    return _moderateProperty(propertyId: propertyId, status: 'approved');
  }

  Future<void> rejectProperty({
    required String propertyId,
    required String reason,
  }) {
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw Exception('Rejection reason is required');
    }
    return _moderateProperty(
      propertyId: propertyId,
      status: 'rejected',
      reason: trimmedReason,
    );
  }

  Future<void> _moderateProperty({
    required String propertyId,
    required String status,
    String? reason,
  }) async {
    final moderator = FirebaseAuth.instance.currentUser;
    if (moderator == null) {
      throw Exception('Admin must be authenticated');
    }

    final propertyRef = _db.collection('properties').doc(propertyId);
    final auditRef = _db.collection('property_audit_logs').doc();

    await _db.runTransaction((txn) async {
      final propertySnap = await txn.get(propertyRef);
      if (!propertySnap.exists) {
        throw Exception('Property not found');
      }

      final property = propertySnap.data() ?? <String, dynamic>{};
      final ownerId = (property['createdBy'] ?? property['uploadedBy'] ?? '').toString();
      final title = (property['title'] ?? 'Property').toString();

      final propertyUpdate = <String, dynamic>{
        'verificationStatus': status,
        'status': status,
        'moderatedBy': moderator.uid,
        'moderatedAt': FieldValue.serverTimestamp(),
      };

      if (status == 'rejected') {
        propertyUpdate['rejectionReason'] = reason;
      } else {
        propertyUpdate['rejectionReason'] = FieldValue.delete();
      }

      txn.update(propertyRef, propertyUpdate);

      txn.set(auditRef, {
        'entityType': 'property',
        'entityId': propertyId,
        'action': 'status_update',
        'fromStatus': property['verificationStatus'] ?? 'pending',
        'toStatus': status,
        'reason': reason,
        'performedBy': moderator.uid,
        'performedAt': FieldValue.serverTimestamp(),
      });

      if (ownerId.isNotEmpty) {
        final activitiesRef = _db.collection('activities').doc();
        final notificationsRef = _db.collection('notifications').doc();
        final statusLabel = status == 'approved' ? 'approved' : 'rejected';
        final description = status == 'approved'
            ? 'Your property "$title" was approved.'
            : 'Your property "$title" was rejected. Reason: $reason';

        txn.set(activitiesRef, {
          'userId': ownerId,
          'type': 'property_$statusLabel',
          'title': 'Property $statusLabel',
          'description': description,
          'entityId': propertyId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        txn.set(notificationsRef, {
          'userId': ownerId,
          'channel': 'firebase',
          'type': 'property_moderation',
          'status': status,
          'title': 'Property $statusLabel',
          'message': description,
          'metadata': {
            'propertyId': propertyId,
            if (reason != null) 'reason': reason,
          },
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
    });
  }
}
