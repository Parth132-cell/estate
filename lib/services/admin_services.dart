import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/services/app_analytics_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../property/property_listing_status.dart';

class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<AdminDashboardMetrics> dashboardMetrics({
    Duration refreshInterval = const Duration(seconds: 30),
  }) async* {
    while (true) {
      yield await _fetchDashboardMetrics();
      await Future<void>.delayed(refreshInterval);
    }
  }

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
        'listingStatus':
            (property['listingStatus'] ?? PropertyListingStatus.active)
                .toString(),
        'status': derivePropertyStatus(
          verificationStatus: status,
          listingStatus:
              (property['listingStatus'] ?? PropertyListingStatus.active)
                  .toString(),
        ),
        'moderatedBy': moderator.uid,
        'moderatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
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

    await AppAnalyticsService.instance.logAdminPropertyModerated(
      status: status,
      propertyId: propertyId,
    );
  }

  Future<AdminDashboardMetrics> _fetchDashboardMetrics() async {
    final totalUsersSnapshot = await _db.collection('users').count().get();
    final totalBrokersSnapshot = await _db
        .collection('users')
        .where('role', isEqualTo: 'broker')
        .count()
        .get();
    final totalPropertiesSnapshot = await _db.collection('properties').count().get();
    final pendingPropertiesSnapshot = await _db
        .collection('properties')
        .where('verificationStatus', isEqualTo: 'pending')
        .count()
        .get();
    final approvedPropertiesSnapshot = await _db
        .collection('properties')
        .where('verificationStatus', isEqualTo: 'approved')
        .count()
        .get();
    final rejectedPropertiesSnapshot = await _db
        .collection('properties')
        .where('verificationStatus', isEqualTo: 'rejected')
        .count()
        .get();
    final totalLeadsSnapshot = await _db.collection('leads').count().get();
    final totalOffersSnapshot = await _db.collection('offers').count().get();
    final todaySnapshot = await _db.collection('admin_metrics_daily').doc(_todayKey).get();

    final todayData = todaySnapshot.data() ?? <String, dynamic>{};
    final rawEventCounters =
        (todayData['eventCounters'] as Map<dynamic, dynamic>? ??
                const <dynamic, dynamic>{})
            .map((key, value) => MapEntry(key.toString(), (value as num).toInt()));

    return AdminDashboardMetrics(
      totalUsers: totalUsersSnapshot.count ?? 0,
      totalBrokers: totalBrokersSnapshot.count ?? 0,
      totalProperties: totalPropertiesSnapshot.count ?? 0,
      pendingProperties: pendingPropertiesSnapshot.count ?? 0,
      approvedProperties: approvedPropertiesSnapshot.count ?? 0,
      rejectedProperties: rejectedPropertiesSnapshot.count ?? 0,
      totalLeads: totalLeadsSnapshot.count ?? 0,
      totalOffers: totalOffersSnapshot.count ?? 0,
      eventCounters: rawEventCounters,
      asOf: (todayData['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  String get _todayKey {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }
}

class AdminDashboardMetrics {
  const AdminDashboardMetrics({
    required this.totalUsers,
    required this.totalBrokers,
    required this.totalProperties,
    required this.pendingProperties,
    required this.approvedProperties,
    required this.rejectedProperties,
    required this.totalLeads,
    required this.totalOffers,
    required this.eventCounters,
    required this.asOf,
  });

  final int totalUsers;
  final int totalBrokers;
  final int totalProperties;
  final int pendingProperties;
  final int approvedProperties;
  final int rejectedProperties;
  final int totalLeads;
  final int totalOffers;
  final Map<String, int> eventCounters;
  final DateTime? asOf;

  int counter(String key) => eventCounters[key] ?? 0;
}
