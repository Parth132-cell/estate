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

  static const Map<String, Set<String>> allowedTransitions = {
    initiated: {paymentPending, cancelled},
    paymentPending: {completed, cancelled},
    completed: {},
    cancelled: {},
  };

  static bool isValid(String value) => all.contains(value);

  static bool canTransition({
    required String from,
    required String to,
  }) {
    if (!isValid(from) || !isValid(to)) {
      return false;
    }
    return (allowedTransitions[from] ?? const <String>{}).contains(to);
  }
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
      status: EscrowState.isValid(status) ? status : EscrowState.initiated,
      createdAt: created,
    );
  }
}

class EscrowAuditLog {
  final String id;
  final String escrowId;
  final String action;
  final String? fromState;
  final String? toState;
  final String? actorId;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const EscrowAuditLog({
    required this.id,
    required this.escrowId,
    required this.action,
    required this.fromState,
    required this.toState,
    required this.actorId,
    required this.metadata,
    required this.createdAt,
  });

  factory EscrowAuditLog.fromMap({
    required String id,
    required String escrowId,
    required Map<String, dynamic>? map,
  }) {
    DateTime created;
    final rawDate = map?['createdAt'];

    if (rawDate is Timestamp) {
      created = rawDate.toDate();
    } else if (rawDate is DateTime) {
      created = rawDate;
    } else {
      created = DateTime.fromMillisecondsSinceEpoch(0);
    }

    return EscrowAuditLog(
      id: id,
      escrowId: escrowId,
      action: (map?['action'] ?? '').toString(),
      fromState: map?['fromState']?.toString(),
      toState: map?['toState']?.toString(),
      actorId: map?['actorId']?.toString(),
      metadata: Map<String, dynamic>.from(map?['metadata'] as Map? ?? {}),
      createdAt: created,
    );
  }
}
