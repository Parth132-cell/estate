import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'review_model.dart';

/// ReviewService — full implementation replacing the stub.
///
/// Writes to:   /reviews/{id}
/// Also writes average rating back to:
///   /properties/{propertyId}  → avgRating, reviewCount
///   /users/{brokerId}         → avgRating, reviewCount
///
/// This keeps property cards and broker profiles up-to-date without
/// needing an extra read every time.
class ReviewService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  ReviewService({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  // ─────────────────────────────────────────
  // WRITE
  // ─────────────────────────────────────────

  /// Add a review.
  /// Throws [ReviewAlreadyExistsException] if this reviewer already reviewed
  /// this deal (prevents duplicate reviews).
  Future<Review> addReview({
    required String dealId,
    required String propertyId,
    required String brokerId,
    required String reviewerId,
    required int rating,
    required String comment,
  }) async {
    // Duplicate guard — one review per (reviewer, deal) pair
    final existing = await _db
        .collection('reviews')
        .where('dealId', isEqualTo: dealId)
        .where('reviewerId', isEqualTo: reviewerId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw ReviewAlreadyExistsException(
        'You have already submitted a review for this deal.',
      );
    }

    final clampedRating = rating.clamp(1, 5);

    final ref = await _db.collection('reviews').add({
      'dealId': dealId,
      'propertyId': propertyId,
      'brokerId': brokerId,
      'reviewerId': reviewerId,
      'rating': clampedRating,
      'comment': comment.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update denormalised averages asynchronously (don't block the caller)
    _updatePropertyStats(propertyId).ignore();
    if (brokerId.isNotEmpty) _updateBrokerStats(brokerId).ignore();

    final snap = await ref.get();
    return Review.fromMap(ref.id, snap.data());
  }

  /// Delete a review (only the author or admin should call this).
  Future<void> deleteReview(String reviewId) async {
    final snap = await _db.collection('reviews').doc(reviewId).get();
    final data = snap.data();
    if (data == null) return;

    await _db.collection('reviews').doc(reviewId).delete();

    // Recalculate averages
    final propertyId = data['propertyId']?.toString() ?? '';
    final brokerId = data['brokerId']?.toString() ?? '';
    if (propertyId.isNotEmpty) _updatePropertyStats(propertyId).ignore();
    if (brokerId.isNotEmpty) _updateBrokerStats(brokerId).ignore();
  }

  // ─────────────────────────────────────────
  // READ — streams
  // ─────────────────────────────────────────

  /// All reviews for a specific broker, newest first.
  Stream<List<Review>> forBroker(String brokerId) {
    return _db
        .collection('reviews')
        .where('brokerId', isEqualTo: brokerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapDocs);
  }

  /// All reviews for a property, newest first.
  Stream<List<Review>> forProperty(String propertyId) {
    return _db
        .collection('reviews')
        .where('propertyId', isEqualTo: propertyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapDocs);
  }

  /// All reviews for a specific deal.
  Stream<List<Review>> forDeal(String dealId) {
    return _db
        .collection('reviews')
        .where('dealId', isEqualTo: dealId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapDocs);
  }

  /// Reviews written by the currently logged-in user.
  Stream<List<Review>> byCurrentUser() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('reviews')
        .where('reviewerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapDocs);
  }

  // ─────────────────────────────────────────
  // READ — futures (one-shot)
  // ─────────────────────────────────────────

  /// Fetch a [ReviewSummary] (average + count + distribution) for a property.
  Future<ReviewSummary> summaryForProperty(String propertyId) async {
    final snap = await _db
        .collection('reviews')
        .where('propertyId', isEqualTo: propertyId)
        .get();
    return ReviewSummary.fromDocs(snap.docs);
  }

  /// Fetch a [ReviewSummary] for a broker.
  Future<ReviewSummary> summaryForBroker(String brokerId) async {
    final snap = await _db
        .collection('reviews')
        .where('brokerId', isEqualTo: brokerId)
        .get();
    return ReviewSummary.fromDocs(snap.docs);
  }

  /// Check if the current user has already reviewed a deal.
  Future<bool> hasReviewedDeal(String dealId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    final snap = await _db
        .collection('reviews')
        .where('dealId', isEqualTo: dealId)
        .where('reviewerId', isEqualTo: uid)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  // ─────────────────────────────────────────
  // PRIVATE HELPERS
  // ─────────────────────────────────────────

  List<Review> _mapDocs(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map((d) => Review.fromMap(d.id, d.data())).toList();

  /// Recompute and write average rating + count back to the property doc.
  Future<void> _updatePropertyStats(String propertyId) async {
    if (propertyId.isEmpty) return;
    try {
      final snap = await _db
          .collection('reviews')
          .where('propertyId', isEqualTo: propertyId)
          .get();
      final summary = ReviewSummary.fromDocs(snap.docs);
      await _db.collection('properties').doc(propertyId).update({
        'avgRating': summary.average,
        'reviewCount': summary.count,
      });
    } catch (_) {
      // Don't let stat updates break the review submission
    }
  }

  /// Recompute and write average rating + count back to the broker user doc.
  Future<void> _updateBrokerStats(String brokerId) async {
    if (brokerId.isEmpty) return;
    try {
      final snap = await _db
          .collection('reviews')
          .where('brokerId', isEqualTo: brokerId)
          .get();
      final summary = ReviewSummary.fromDocs(snap.docs);
      await _db.collection('users').doc(brokerId).update({
        'avgRating': summary.average,
        'reviewCount': summary.count,
      });
    } catch (_) {}
  }
}

// ─────────────────────────────────────────
// REVIEW SUMMARY
// ─────────────────────────────────────────

/// Aggregated stats computed client-side from a list of review docs.
class ReviewSummary {
  final double average;
  final int count;
  final Map<int, int> distribution; // star → count

  const ReviewSummary({
    required this.average,
    required this.count,
    required this.distribution,
  });

  static ReviewSummary fromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (docs.isEmpty) {
      return const ReviewSummary(average: 0, count: 0, distribution: {});
    }
    final dist = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    int total = 0;
    for (final d in docs) {
      final r = ((d.data()['rating'] as num?) ?? 0).clamp(1, 5).toInt();
      dist[r] = (dist[r] ?? 0) + 1;
      total += r;
    }
    return ReviewSummary(
      average: total / docs.length,
      count: docs.length,
      distribution: dist,
    );
  }

  String get displayAverage => average.toStringAsFixed(1);

  bool get isEmpty => count == 0;
}

// ─────────────────────────────────────────
// EXCEPTIONS
// ─────────────────────────────────────────

class ReviewAlreadyExistsException implements Exception {
  final String message;
  const ReviewAlreadyExistsException(this.message);
  @override
  String toString() => 'ReviewAlreadyExistsException: $message';
}
