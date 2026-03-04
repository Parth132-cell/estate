import 'package:cloud_firestore/cloud_firestore.dart';

class FraudDetectionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<int> scanAndCreateAlerts() async {
    final props = await _db.collection('properties').get();
    int count = 0;

    for (final doc in props.docs) {
      final d = doc.data();
      final price = (d['price'] as num?)?.toInt() ?? 0;
      final images = (d['images'] as List?) ?? [];

      if (price <= 0 || images.isEmpty) {
        await _db.collection('fraud_alerts').add({
          'entityType': 'property',
          'entityId': doc.id,
          'reason': price <= 0 ? 'invalid_price' : 'missing_images',
          'severity': 'medium',
          'status': 'open',
          'createdAt': FieldValue.serverTimestamp(),
        });
        count++;
      }
    }

    return count;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> alerts() {
    return _db
        .collection('fraud_alerts')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> resolveAlert(String alertId) async {
    await _db.collection('fraud_alerts').doc(alertId).update({
      'status': 'resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }
}
