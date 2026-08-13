import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'property_listing_repository.dart';

class SavedSearch {
  const SavedSearch({
    required this.id,
    required this.label,
    required this.userId,
    required this.city,
    required this.locality,
    required this.bhk,
    required this.minPrice,
    required this.maxPrice,
    required this.sort,
    required this.alertEnabled,
    required this.createdAt,
  });

  final String id;
  final String label;
  final String userId;
  final String city;
  final String locality;
  final int? bhk;
  final int? minPrice;
  final int? maxPrice;
  final PropertySort sort;
  final bool alertEnabled;
  final DateTime? createdAt;

  PropertyFilter toFilter() {
    return PropertyFilter(
      city: city,
      locality: locality,
      bhk: bhk,
      minPrice: minPrice,
      maxPrice: maxPrice,
      sort: sort,
    );
  }

  factory SavedSearch.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    return SavedSearch(
      id: doc.id,
      label: (data['label'] ?? 'Saved search').toString(),
      userId: (data['userId'] ?? '').toString(),
      city: (data['city'] ?? '').toString(),
      locality: (data['locality'] ?? '').toString(),
      bhk: (data['bhk'] as num?)?.toInt(),
      minPrice: (data['minPrice'] as num?)?.toInt(),
      maxPrice: (data['maxPrice'] as num?)?.toInt(),
      sort: switch ((data['sort'] ?? '').toString()) {
        'priceLowToHigh' => PropertySort.priceLowToHigh,
        'priceHighToLow' => PropertySort.priceHighToLow,
        _ => PropertySort.newest,
      },
      alertEnabled: data['alertEnabled'] != false,
      createdAt: switch (data['createdAt']) {
        final Timestamp timestamp => timestamp.toDate(),
        _ => null,
      },
    );
  }
}

class SavedSearchService {
  SavedSearchService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Please sign in to save searches');
    }
    return user.uid;
  }

  Stream<List<SavedSearch>> watchSavedSearches() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream<List<SavedSearch>>.empty();
    }

    return _db
        .collection('saved_searches')
        .where('userId', isEqualTo: user.uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(SavedSearch.fromDoc)
              .toList(growable: false),
        );
  }

  Future<void> saveSearch({
    required PropertyFilter filter,
    String? label,
  }) async {
    if (filter.normalizedCity.isEmpty) {
      throw Exception('Select at least a city before saving an alert');
    }

    final city = filter.city?.trim() ?? '';
    final locality = filter.locality?.trim() ?? '';
    final bhkLabel = filter.bhk == null ? '' : ' • ${filter.bhk} BHK';
    final localityLabel = locality.isEmpty ? '' : ' • $locality';
    final documentId = _docId(_uid, filter);

    await _db.collection('saved_searches').doc(documentId).set({
      'userId': _uid,
      'label':
          label?.trim().isNotEmpty == true
              ? label!.trim()
              : '$city$localityLabel$bhkLabel',
      'city': city,
      'cityLower': filter.normalizedCity,
      'locality': locality,
      'localityLower': filter.normalizedLocality,
      'bhk': filter.bhk,
      'minPrice': filter.minPrice,
      'maxPrice': filter.maxPrice,
      'sort': filter.sort.name,
      'alertEnabled': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteSavedSearch(String savedSearchId) {
    return _db.collection('saved_searches').doc(savedSearchId).delete();
  }

  static String _docId(String uid, PropertyFilter filter) {
    final raw =
        '$uid|${filter.normalizedCity}|${filter.normalizedLocality}|${filter.bhk ?? 'any'}|${filter.minPrice ?? 'any'}|${filter.maxPrice ?? 'any'}|${filter.sort.name}';
    return raw.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  }
}
