import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DealServices {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.uid;
  }

  Future<void> createOffer({
    required String propertyId,
    required String sellerId,
    required int amount,
  }) async {
    final buyerId = _uid;
    final now = FieldValue.serverTimestamp();

    await _db.collection('offers').add({
      'propertyId': propertyId,
      'buyerId': buyerId,
      'sellerId': sellerId,
      'amount': amount,
      'status': 'pending',
      'history': [
        {
          'action': 'offer_sent',
          'actorId': buyerId,
          'amount': amount,
          'at': now,
        },
      ],
      'createdAt': now,
      'updatedAt': now,
    });

    await _createNotification(
      userId: sellerId,
      title: 'New offer received',
      message: 'A buyer submitted an offer of ₹$amount.',
      type: 'offer_created',
      metadata: {
        'propertyId': propertyId,
        'buyerId': buyerId,
        'sellerId': sellerId,
        'amount': amount,
      },
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> buyerDeals() {
    return _db
        .collection('offers')
        .where('buyerId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> brokerDeals() {
    return _db
        .collection('offers')
        .where('sellerId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> updateDealStatus(String dealId, String status) async {
    final offerRef = _db.collection('offers').doc(dealId);

    await _db.runTransaction((txn) async {
      final snap = await txn.get(offerRef);
      if (!snap.exists) {
        throw Exception('Offer not found');
      }

      final data = snap.data() ?? <String, dynamic>{};
      final history = List<Map<String, dynamic>>.from(
        ((data['history'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map)),
      );

      history.add({
        'action': 'status_changed',
        'actorId': _uid,
        'status': status,
        'at': FieldValue.serverTimestamp(),
      });

      txn.update(offerRef, {
        'status': status,
        'history': history,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final buyerId = (data['buyerId'] ?? '').toString();
      if (buyerId.isNotEmpty) {
        txn.set(_db.collection('notifications').doc(), {
          'userId': buyerId,
          'actorId': _uid,
          'channel': 'in_app',
          'type': 'offer_status_update',
          'status': status,
          'title': 'Offer $status',
          'message': 'Seller has marked your offer as $status.',
          'metadata': {'offerId': dealId, 'status': status},
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
    });
  }

  Future<void> counterOffer({
    required String dealId,
    required int counterAmount,
  }) async {
    final offerRef = _db.collection('offers').doc(dealId);

    await _db.runTransaction((txn) async {
      final snap = await txn.get(offerRef);
      if (!snap.exists) {
        throw Exception('Offer not found');
      }

      final data = snap.data() ?? <String, dynamic>{};
      final history = List<Map<String, dynamic>>.from(
        ((data['history'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map)),
      );

      history.add({
        'action': 'counter_sent',
        'actorId': _uid,
        'amount': counterAmount,
        'at': FieldValue.serverTimestamp(),
      });

      txn.update(offerRef, {
        'amount': counterAmount,
        'status': 'counter',
        'history': history,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final buyerId = (data['buyerId'] ?? '').toString();
      if (buyerId.isNotEmpty) {
        txn.set(_db.collection('notifications').doc(), {
          'userId': buyerId,
          'actorId': _uid,
          'channel': 'in_app',
          'type': 'counter_offer',
          'status': 'counter',
          'title': 'Counter-offer received',
          'message': 'Seller countered with ₹$counterAmount.',
          'metadata': {
            'offerId': dealId,
            'counterAmount': counterAmount,
            'propertyId': data['propertyId'],
          },
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
    });
  }

  Future<void> _createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? metadata,
  }) async {
    await _db.collection('notifications').add({
      'userId': userId,
      'actorId': _uid,
      'channel': 'in_app',
      'type': type,
      'title': title,
      'message': message,
      'metadata': metadata ?? <String, dynamic>{},
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
  }
}
