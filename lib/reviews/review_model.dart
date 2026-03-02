import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String dealId;
  final String propertyId;
  final String brokerId;
  final String reviewerId;
  final int rating; // 1 to 5
  final String comment;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.dealId,
    required this.propertyId,
    required this.brokerId,
    required this.reviewerId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory Review.fromMap(String id, Map<String, dynamic>? map) {
    if (map == null) {
      return Review(
        id: id,
        dealId: '',
        propertyId: '',
        brokerId: '',
        reviewerId: '',
        rating: 0,
        comment: '',
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

    return Review(
      id: id,
      dealId: map['dealId'] ?? '',
      propertyId: map['propertyId'] ?? '',
      brokerId: map['brokerId'] ?? '',
      reviewerId: map['reviewerId'] ?? '',
      rating: (map['rating'] is num)
          ? (map['rating'] as num).clamp(0, 5).toInt()
          : 0,
      comment: map['comment'] ?? '',
      createdAt: created,
    );
  }
}
