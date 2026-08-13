import 'package:cloud_firestore/cloud_firestore.dart';

enum PropertySort { newest, priceLowToHigh, priceHighToLow }

class PropertyFilter {
  const PropertyFilter({
    this.city,
    this.locality,
    this.bhk,
    this.minPrice,
    this.maxPrice,
    this.propertyCategory,
    this.sort = PropertySort.newest,
  });

  final String? city;
  final String? locality;
  final int? bhk;
  final int? minPrice;
  final int? maxPrice;
  final String? propertyCategory;
  final PropertySort sort;

  bool get hasPriceRange => minPrice != null || maxPrice != null;
  bool get hasAnyFilter =>
      normalizedCity.isNotEmpty ||
      normalizedLocality.isNotEmpty ||
      bhk != null ||
      hasPriceRange ||
      propertyCategory != null;

  String get normalizedCity => city?.trim().toLowerCase() ?? '';
  String get normalizedLocality => locality?.trim().toLowerCase() ?? '';

  String get sortLabel => switch (sort) {
    PropertySort.newest => 'Newest',
    PropertySort.priceLowToHigh => 'Price: Low to High',
    PropertySort.priceHighToLow => 'Price: High to Low',
  };

  String get cacheKey =>
      'city:$normalizedCity|locality:$normalizedLocality|bhk:${bhk ?? 'any'}|cat:${propertyCategory ?? 'any'}|min:${minPrice ?? 'any'}|max:${maxPrice ?? 'any'}|sort:${sort.name}';
}

class PropertyListing {
  const PropertyListing({
    required this.id,
    required this.title,
    required this.city,
    required this.locality,
    required this.price,
    required this.bhk,
    required this.imageUrls,
    required this.brokerId,
    required this.verified,
    required this.createdAt,
    required this.latitude,
    required this.longitude,
    this.areaSqft,
    this.propertyCategory = 'apartment',
  });

  final String id;
  final String title;
  final String city;
  final String locality;
  final int price;
  final int bhk;
  final List<String> imageUrls;
  final String brokerId;
  final bool verified;
  final DateTime? createdAt;
  final double latitude;
  final double longitude;
  final int? areaSqft;
  final String propertyCategory;

  String get locationLabel =>
      locality.trim().isEmpty ? city : '$locality, $city';

  factory PropertyListing.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final images =
        (data['images'] as List?) ?? (data['imageUrls'] as List?) ?? [];
    final city = (data['city'] ?? 'Unknown city').toString();
    final locality = (data['locality'] ?? '').toString();
    final latitude =
        _readCoordinate(data, const ['latitude', 'lat']) ??
        _readNestedCoordinate(data, 'searchLocation', 'latitude') ??
        _cityFallbackLatitude(city, locality, doc.id);
    final longitude =
        _readCoordinate(data, const ['longitude', 'lng', 'lon']) ??
        _readNestedCoordinate(data, 'searchLocation', 'longitude') ??
        _cityFallbackLongitude(city, locality, doc.id);

    return PropertyListing(
      id: doc.id,
      title: (data['title'] ?? 'Untitled property').toString(),
      city: city,
      locality: locality,
      price: (data['price'] as num?)?.toInt() ?? 0,
      bhk: (data['bhk'] as num?)?.toInt() ?? 0,
      imageUrls: images.map((e) => e.toString()).toList(growable: false),
      brokerId: (data['uploadedBy'] ?? data['createdBy'] ?? '').toString(),
      verified:
          (data['verificationStatus'] ?? '').toString().toLowerCase() ==
          'approved',
      createdAt: switch (data['createdAt']) {
        final Timestamp timestamp => timestamp.toDate(),
        _ => null,
      },
      latitude: latitude,
      longitude: longitude,
      areaSqft: (data['areaSqft'] as num?)?.toInt(),
      propertyCategory: (data['propertyCategory'] ?? 'apartment').toString(),
    );
  }

  static double? _readCoordinate(
    Map<String, dynamic> data,
    List<String> candidates,
  ) {
    for (final key in candidates) {
      final raw = data[key];
      if (raw is num) {
        return raw.toDouble();
      }
      if (raw is String) {
        final parsed = double.tryParse(raw.trim());
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  static double? _readNestedCoordinate(
    Map<String, dynamic> data,
    String parentKey,
    String childKey,
  ) {
    final parent = data[parentKey];
    if (parent is! Map) {
      return null;
    }

    final raw = parent[childKey];
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      return double.tryParse(raw.trim());
    }
    return null;
  }

  static double _cityFallbackLatitude(
    String city,
    String locality,
    String seed,
  ) {
    final center = _cityCenter(city);
    final offset = _stableOffset('$city|$locality|$seed');
    return center.$1 + offset.$1;
  }

  static double _cityFallbackLongitude(
    String city,
    String locality,
    String seed,
  ) {
    final center = _cityCenter(city);
    final offset = _stableOffset('$city|$locality|$seed');
    return center.$2 + offset.$2;
  }

  static (double, double) _cityCenter(String city) {
    switch (city.trim().toLowerCase()) {
      case 'bangalore':
      case 'bengaluru':
        return (12.9716, 77.5946);
      case 'mumbai':
        return (19.0760, 72.8777);
      case 'delhi':
      case 'new delhi':
        return (28.6139, 77.2090);
      case 'hyderabad':
        return (17.3850, 78.4867);
      case 'chennai':
        return (13.0827, 80.2707);
      case 'pune':
        return (18.5204, 73.8567);
      case 'kolkata':
        return (22.5726, 88.3639);
      case 'ahmedabad':
        return (23.0225, 72.5714);
      default:
        return (20.5937, 78.9629);
    }
  }

  static (double, double) _stableOffset(String input) {
    var hash = 0;
    for (final unit in input.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }

    final latOffset = ((hash % 1000) / 1000.0 - 0.5) * 0.08;
    final lngOffset = (((hash ~/ 1000) % 1000) / 1000.0 - 0.5) * 0.08;
    return (latOffset, lngOffset);
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

    if (filter.normalizedLocality.isNotEmpty) {
      query = query.where(
        'locality_lower',
        isEqualTo: filter.normalizedLocality,
      );
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

    return switch (filter.sort) {
      PropertySort.newest => query.orderBy('createdAt', descending: true),
      PropertySort.priceLowToHigh =>
        query.orderBy('price').orderBy('createdAt', descending: true),
      PropertySort.priceHighToLow =>
        query
            .orderBy('price', descending: true)
            .orderBy('createdAt', descending: true),
    };
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
      final snapshot = await pageQuery.get(
        const GetOptions(source: Source.serverAndCache),
      );
      final docs = snapshot.docs;
      final items = docs.map(PropertyListing.fromDoc).toList(growable: false);

      if (startAfter == null) {
        _cache[key] = items;
      } else {
        _cache[key] = [...?_cache[key], ...items];
      }

      return ListingPageResult(
        items: items,
        lastDoc: docs.isEmpty ? startAfter : docs.last,
        hasMore: docs.length == pageSize,
        fromCache:
            snapshot.metadata.isFromCache &&
            !snapshot.metadata.hasPendingWrites,
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

  List<PropertyListing>? getCached(PropertyFilter filter) =>
      _cache[filter.cacheKey];
}
