import 'package:cloud_firestore/cloud_firestore.dart';

class EscrowState {
  static const String initiated = 'initiated';
  static const String paymentPending = 'payment_pending';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';

  static const Set<String> all = {
    initiated,
    paymentPending,
    completed,
    cancelled,
  };
}

class EscrowTransaction {
  final String id;
  final String dealId;
  final String buyerId;
  final double amount;
  final String status;
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
        status: EscrowState.initiated,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
    }

    DateTime created;
    final rawDate = map['createdAt'];

    if (rawDate is Timestamp) {
      created = rawDate.toDate();
    } else if (rawDate is DateTime) {
      created = rawDate;
    } else {
      created = DateTime.fromMillisecondsSinceEpoch(0);
    }

    final status = (map['status'] ?? EscrowState.initiated).toString();

    return EscrowTransaction(
      id: id,
      dealId: map['dealId'] ?? '',
      buyerId: map['buyerId'] ?? '',
      amount: (map['amount'] is num) ? (map['amount'] as num).toDouble() : 0.0,
      status: EscrowState.all.contains(status)
          ? status
          : EscrowState.initiated,
      createdAt: created,
    );
  }
}
