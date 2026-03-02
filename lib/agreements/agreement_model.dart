import 'package:cloud_firestore/cloud_firestore.dart';

class Agreement {
  final String id;
  final String dealId;
  final String buyerId;
  final String brokerId;
  final String status; // draft | accepted | rejected
  final DateTime createdAt;

  const Agreement({
    required this.id,
    required this.dealId,
    required this.buyerId,
    required this.brokerId,
    required this.status,
    required this.createdAt,
  });

  factory Agreement.fromMap(String id, Map<String, dynamic>? map) {
    if (map == null) {
      return Agreement(
        id: id,
        dealId: '',
        buyerId: '',
        brokerId: '',
        status: 'draft',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
    }

    // Safe DateTime parsing
    DateTime created;
    final rawDate = map['createdAt'];

    if (rawDate is Timestamp) {
      created = rawDate.toDate();
    } else if (rawDate is DateTime) {
      created = rawDate;
    } else {
      created = DateTime.fromMillisecondsSinceEpoch(0);
    }

    return Agreement(
      id: id,
      dealId: map['dealId'] ?? '',
      buyerId: map['buyerId'] ?? '',
      brokerId: map['brokerId'] ?? '',
      status: map['status'] ?? 'draft',
      createdAt: created,
    );
  }
}
