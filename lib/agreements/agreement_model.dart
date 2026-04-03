import 'package:cloud_firestore/cloud_firestore.dart';

class Agreement {
  final String id;
  final String dealId;
  final String buyerId;
  final String sellerId;
  final String status; // draft | accepted | rejected
  final String esignStatus; // not_sent | pending_buyer | pending_seller | completed
  final String? pdfUrl;
  final DateTime createdAt;

  const Agreement({
    required this.id,
    required this.dealId,
    required this.buyerId,
    required this.sellerId,
    required this.status,
    required this.esignStatus,
    required this.createdAt,
    this.pdfUrl,
  });

  bool get isFinalized => status == 'accepted' || status == 'rejected';

  factory Agreement.fromMap(String id, Map<String, dynamic>? map) {
    if (map == null) {
      return Agreement(
        id: id,
        dealId: '',
        buyerId: '',
        sellerId: '',
        status: 'draft',
        esignStatus: 'not_sent',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
    }

    final rawDate = map['createdAt'];
    final created = switch (rawDate) {
      Timestamp() => rawDate.toDate(),
      DateTime() => rawDate,
      _ => DateTime.fromMillisecondsSinceEpoch(0),
    };

    return Agreement(
      id: id,
      dealId: (map['dealId'] ?? '').toString(),
      buyerId: (map['buyerId'] ?? '').toString(),
      sellerId: (map['sellerId'] ?? map['brokerId'] ?? '').toString(),
      status: (map['status'] ?? 'draft').toString(),
      esignStatus: (map['esignStatus'] ?? 'not_sent').toString(),
      pdfUrl: map['pdfUrl']?.toString(),
      createdAt: created,
    );
  }
}
