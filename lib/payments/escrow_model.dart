import 'package:cloud_firestore/cloud_firestore.dart';

class EscrowTransaction {
  final String id;
  final String dealId;
  final String buyerId;
  final double amount;
  final String status; // held | released | refunded
  final DateTime createdAt;

  const EscrowTransaction({
    required this.id,
    required this.dealId,
    required this.buyerId,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  factory EscrowTransaction.fromMap(String id, Map<String, dynamic>? map) {
    if (map == null) {
      return EscrowTransaction(
        id: id,
        dealId: '',
        buyerId: '',
        amount: 0.0,
        status: 'held',
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

    return EscrowTransaction(
      id: id,
      dealId: map['dealId'] ?? '',
      buyerId: map['buyerId'] ?? '',
      amount: (map['amount'] is num) ? (map['amount'] as num).toDouble() : 0.0,
      status: map['status'] ?? 'held',
      createdAt: created,
    );
  }
}
