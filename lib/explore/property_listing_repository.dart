import 'package:cloud_firestore/cloud_firestore.dart';

class PropertyFilter {
  const PropertyFilter({
    this.city,
    this.bhk,
    this.minPrice,
    this.maxPrice,
  });

  final String? city;
  final int? bhk;
  final int? minPrice;
  final int? maxPrice;

  bool get hasPriceRange => minPrice != null || maxPrice != null;

  String get normalizedCity => city?.trim().toLowerCase() ?? '';

  String get cacheKey =>
      'city:$normalizedCity|bhk:${bhk ?? 'any'}|min:${minPrice ?? 'any'}|max:${maxPrice ?? 'any'}';
}

class PropertyListing {
  const PropertyListing({
    required this.id,
    required this.title,
    required this.city,
    required this.price,
    required this.bhk,
    required this.imageUrls,
    required this.brokerId,
    required this.verified,
  });

  final String id;
  final String title;
  final String city;
  final int price;
  final int bhk;
  final List<String> imageUrls;
  final String brokerId;
  final bool verified;

  factory PropertyListing.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final images = (data['images'] as List?) ?? (data['imageUrls'] as List?) ?? [];

    return PropertyListing(
      id: doc.id,
      title: (data['title'] ?? 'Untitled property').toString(),
      city: (data['city'] ?? 'Unknown city').toString(),
      price: (data['price'] as num?)?.toInt() ?? 0,
      bhk: (data['bhk'] as num?)?.toInt() ?? 0,
      imageUrls: images.map((e) => e.toString()).toList(),
      brokerId: (data['uploadedBy'] ?? data['createdBy'] ?? '').toString(),
      verified: (data['verificationStatus'] ?? '').toString().toLowerCase() == 'approved',
    );
  }
}

class ListingPageResult {
  const ListingPageResult({
    required this.items,
    required this.lastDoc,
    required this.hasMore,
    required this.fromCache,
  });

  final List<PropertyListing> items;
  final QueryDocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;
  final bool fromCache;
}

class PropertyListingRepository {
  PropertyListingRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final Map<String, List<PropertyListing>> _cache = {};

  static const int pageSize = 12;

  Query<Map<String, dynamic>> _buildQuery(PropertyFilter filter) {
    Query<Map<String, dynamic>> query = _db
        .collection('properties')
        .where('verificationStatus', isEqualTo: 'approved');

    if (filter.normalizedCity.isNotEmpty) {
      query = query.where('city_lower', isEqualTo: filter.normalizedCity);
    }

    if (filter.bhk != null) {
      query = query.where('bhk', isEqualTo: filter.bhk);
    }

    if (filter.minPrice != null) {
      query = query.where('price', isGreaterThanOrEqualTo: filter.minPrice);
    }

    if (filter.maxPrice != null) {
      query = query.where('price', isLessThanOrEqualTo: filter.maxPrice);
    }

    if (filter.hasPriceRange) {
      return query.orderBy('price').orderBy('createdAt', descending: true);
    }

    return query.orderBy('createdAt', descending: true);
  }

  Future<ListingPageResult> fetchPage({
    required PropertyFilter filter,
    QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    final key = filter.cacheKey;
    final query = _buildQuery(filter);
    var pageQuery = query.limit(pageSize);
    if (startAfter != null) {
      pageQuery = pageQuery.startAfterDocument(startAfter);
    }

    try {
      final snapshot = await pageQuery.get(const GetOptions(source: Source.serverAndCache));
      final docs = snapshot.docs;
      final items = docs.map(PropertyListing.fromDoc).toList();

      if (startAfter == null) {
        _cache[key] = items;
      } else {
        _cache[key] = [...?_cache[key], ...items];
      }

      return ListingPageResult(
        items: items,
        lastDoc: docs.isEmpty ? startAfter : docs.last,
        hasMore: docs.length == pageSize,
        fromCache: snapshot.metadata.isFromCache && !snapshot.metadata.hasPendingWrites,
      );
    } catch (_) {
      if (_cache.containsKey(key)) {
        final cached = _cache[key]!;
        return ListingPageResult(
          items: startAfter == null ? cached : const [],
          lastDoc: startAfter,
          hasMore: false,
          fromCache: true,
        );
      }
      rethrow;
    }
  }

  List<PropertyListing>? getCached(PropertyFilter filter) => _cache[filter.cacheKey];
}
