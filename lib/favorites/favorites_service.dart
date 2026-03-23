import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoritePage {
  const FavoritePage({
    required this.items,
    required this.lastDocument,
    required this.hasMore,
  });

  final List<FavoritePropertyItem> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
}

class FavoritePropertyItem {
  const FavoritePropertyItem({
    required this.propertyId,
    required this.createdAt,
    this.property,
    this.isDeleted = false,
  });

  final String propertyId;
  final DateTime? createdAt;
  final Map<String, dynamic>? property;
  final bool isDeleted;
}

abstract class FavoritesRepository {
  Stream<Set<String>> watchFavoriteIds();
  Future<void> setFavorite({required String propertyId, required bool isFavorite});
  Future<FavoritePage> fetchFavoritesPage({
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
    int limit = 12,
  });
}

class FavoritesService implements FavoritesRepository {
  FavoritesService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User is not authenticated');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _favoritesRef =>
      _firestore.collection('users').doc(_uid).collection('favorites');

  bool _isFavoriteDoc(Map<String, dynamic> data) {
    if (data['isFavorite'] is bool) {
      return data['isFavorite'] == true;
    }
    return data['forComparison'] != true;
  }

  @override
  Stream<Set<String>> watchFavoriteIds() {
    return _favoritesRef.snapshots().map(
      (snapshot) => snapshot.docs
          .where((doc) => _isFavoriteDoc(doc.data()))
          .map((doc) => (doc.data()['propertyId'] ?? doc.id).toString())
          .where((id) => id.isNotEmpty)
          .toSet(),
    );
  }

  @override
  Future<void> setFavorite({
    required String propertyId,
    required bool isFavorite,
  }) async {
    final docRef = _favoritesRef.doc(propertyId);
    final doc = await docRef.get();
    final existing = doc.data() ?? <String, dynamic>{};
    final inComparison = existing['forComparison'] == true;

    if (!isFavorite) {
      if (inComparison) {
        await docRef.set({
          'propertyId': propertyId,
          'isFavorite': false,
          'forComparison': true,
          'createdAt': existing['createdAt'] ?? FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await docRef.delete();
      }
      return;
    }

    await docRef.set({
      'propertyId': propertyId,
      'isFavorite': true,
      'forComparison': inComparison,
      'createdAt': existing['createdAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<FavoritePage> fetchFavoritesPage({
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
    int limit = 12,
  }) async {
    Query<Map<String, dynamic>> query =
        _favoritesRef.orderBy('createdAt', descending: true).limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    final favoriteSnapshot = await query.get();
    final docs = favoriteSnapshot.docs;

    final items = <FavoritePropertyItem>[];

    for (final doc in docs.where((d) => _isFavoriteDoc(d.data()))) {
      final propertyId = (doc.data()['propertyId'] ?? doc.id).toString();
      final propertyDoc =
          await _firestore.collection('properties').doc(propertyId).get();
      final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();

      if (!propertyDoc.exists) {
        items.add(
          FavoritePropertyItem(
            propertyId: propertyId,
            createdAt: createdAt,
            isDeleted: true,
          ),
        );
        continue;
      }

      items.add(
        FavoritePropertyItem(
          propertyId: propertyId,
          createdAt: createdAt,
          property: propertyDoc.data(),
        ),
      );
    }

    return FavoritePage(
      items: items,
      lastDocument: docs.isNotEmpty ? docs.last : lastDocument,
      hasMore: docs.length == limit,
    );
  }
}
