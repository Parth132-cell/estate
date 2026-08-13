import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../property/image_upload_service.dart';
import '../property/property_listing_status.dart';

class PropertyUpsertInput {
  const PropertyUpsertInput({
    required this.title,
    required this.price,
    required this.city,
    required this.locality,
    required this.latitude,
    required this.longitude,
    required this.areaSqft,
    required this.description,
    required this.bhk,
    required this.listingType,
    required this.existingImageUrls,
    required this.newImages,
    this.propertyCategory = 'apartment',
  });

  final String title;
  final int? price;
  final String city;
  final String locality;
  final double? latitude;
  final double? longitude;
  final int? areaSqft;
  final String description;
  final int? bhk;
  final String listingType;
  final List<String> existingImageUrls;
  final List<File> newImages;

  /// e.g. 'apartment' | 'house' | 'villa' | 'plot' | 'land' | 'commercial' | 'warehouse'
  final String propertyCategory;
}

class PropertyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ImageUploadService _imageUploadService = ImageUploadService();

  Future<String> saveDraft({
    String? propertyId,
    required PropertyUpsertInput input,
    required void Function(double progress) onUploadProgress,
  }) async {
    return _upsertProperty(
      propertyId: propertyId,
      input: input,
      verificationStatus: PropertyVerificationStatus.draft,
      listingStatus: PropertyListingStatus.draft,
      onUploadProgress: onUploadProgress,
      incrementResubmissionCount: false,
      activityType: 'property_draft_saved',
      activityTitle: 'Property draft saved',
      activityDescription: 'Your property draft was saved.',
    );
  }

  Future<String> submitProperty({
    String? propertyId,
    required PropertyUpsertInput input,
    required void Function(double progress) onUploadProgress,
  }) async {
    _validateReadyForReview(input);

    return _upsertProperty(
      propertyId: propertyId,
      input: input,
      verificationStatus: PropertyVerificationStatus.pending,
      listingStatus: PropertyListingStatus.active,
      onUploadProgress: onUploadProgress,
      incrementResubmissionCount: false,
      activityType: 'property_submitted',
      activityTitle: 'Property submitted',
      activityDescription: 'Your property is under review.',
    );
  }

  Future<String> resubmitRejectedProperty({
    required String propertyId,
    required PropertyUpsertInput input,
    required void Function(double progress) onUploadProgress,
  }) async {
    _validateReadyForReview(input);

    return _upsertProperty(
      propertyId: propertyId,
      input: input,
      verificationStatus: PropertyVerificationStatus.pending,
      listingStatus: PropertyListingStatus.active,
      onUploadProgress: onUploadProgress,
      incrementResubmissionCount: true,
      activityType: 'property_resubmitted',
      activityTitle: 'Property resubmitted',
      activityDescription: 'Your rejected property was resubmitted for review.',
      clearRejectionReason: true,
    );
  }

  Future<String> updateListing({
    required String propertyId,
    required PropertyUpsertInput input,
    required void Function(double progress) onUploadProgress,
  }) async {
    final snapshot = await _db.collection('properties').doc(propertyId).get();
    final existing = snapshot.data() ?? const <String, dynamic>{};
    final currentVerificationStatus =
        (existing['verificationStatus'] ?? PropertyVerificationStatus.pending)
            .toString();

    final nextVerificationStatus =
        currentVerificationStatus == PropertyVerificationStatus.approved
        ? PropertyVerificationStatus.pending
        : currentVerificationStatus == PropertyVerificationStatus.rejected
        ? PropertyVerificationStatus.pending
        : currentVerificationStatus == PropertyVerificationStatus.draft
        ? PropertyVerificationStatus.draft
        : PropertyVerificationStatus.pending;

    final nextListingStatus =
        nextVerificationStatus == PropertyVerificationStatus.draft
        ? PropertyListingStatus.draft
        : PropertyListingStatus.active;

    if (nextVerificationStatus != PropertyVerificationStatus.draft) {
      _validateReadyForReview(input);
    }

    return _upsertProperty(
      propertyId: propertyId,
      input: input,
      verificationStatus: nextVerificationStatus,
      listingStatus: nextListingStatus,
      onUploadProgress: onUploadProgress,
      incrementResubmissionCount:
          currentVerificationStatus == PropertyVerificationStatus.rejected,
      activityType: 'property_updated',
      activityTitle: 'Property updated',
      activityDescription:
          nextVerificationStatus == PropertyVerificationStatus.pending
          ? 'Your property changes were sent for review.'
          : 'Your property draft was updated.',
      clearRejectionReason:
          currentVerificationStatus == PropertyVerificationStatus.rejected,
    );
  }

  Future<void> markAsSold(String propertyId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Only authenticated users can manage properties');
    }

    await _db.collection('properties').doc(propertyId).set({
      'listingStatus': PropertyListingStatus.sold,
      'status': PropertyListingStatus.sold,
      'soldAt': FieldValue.serverTimestamp(),
      'soldBy': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastSellerActionAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _logActivity(
      userId: user.uid,
      entityId: propertyId,
      type: 'property_marked_sold',
      title: 'Property marked sold',
      description: 'Your property listing was marked as sold.',
    );
  }

  Future<void> archiveListing(String propertyId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Only authenticated users can manage properties');
    }

    await _db.collection('properties').doc(propertyId).set({
      'listingStatus': PropertyListingStatus.archived,
      'status': PropertyListingStatus.archived,
      'archivedAt': FieldValue.serverTimestamp(),
      'archivedBy': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastSellerActionAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _logActivity(
      userId: user.uid,
      entityId: propertyId,
      type: 'property_archived',
      title: 'Property archived',
      description: 'Your property listing was archived.',
    );
  }

  Future<void> restoreListing(String propertyId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Only authenticated users can manage properties');
    }

    final snapshot = await _db.collection('properties').doc(propertyId).get();
    final data = snapshot.data() ?? const <String, dynamic>{};
    final verificationStatus =
        (data['verificationStatus'] ?? PropertyVerificationStatus.pending)
            .toString();

    final restoredListingStatus =
        verificationStatus == PropertyVerificationStatus.draft
        ? PropertyListingStatus.draft
        : PropertyListingStatus.active;

    await _db.collection('properties').doc(propertyId).set({
      'listingStatus': restoredListingStatus,
      'status': derivePropertyStatus(
        verificationStatus: verificationStatus,
        listingStatus: restoredListingStatus,
      ),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastSellerActionAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _logActivity(
      userId: user.uid,
      entityId: propertyId,
      type: 'property_restored',
      title: 'Property restored',
      description: 'Your archived property listing was restored.',
    );
  }

  Future<String> _upsertProperty({
    String? propertyId,
    required PropertyUpsertInput input,
    required String verificationStatus,
    required String listingStatus,
    required void Function(double progress) onUploadProgress,
    required bool incrementResubmissionCount,
    required String activityType,
    required String activityTitle,
    required String activityDescription,
    bool clearRejectionReason = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Only authenticated users can submit properties');
    }

    final isCreating = propertyId == null;
    final docRef = isCreating
        ? _db.collection('properties').doc()
        : _db.collection('properties').doc(propertyId);
    final existingSnapshot = isCreating ? null : await docRef.get();
    final existingData = existingSnapshot?.data() ?? <String, dynamic>{};

    await user.reload();
    await user.getIdToken(true);

    final uploadedImageUrls = await _uploadNewImages(
      propertyId: docRef.id,
      ownerId: user.uid,
      images: input.newImages,
      onUploadProgress: onUploadProgress,
    );
    final finalImageUrls = <String>[
      ...input.existingImageUrls,
      ...uploadedImageUrls,
    ];

    final normalizedTitle = input.title.trim();
    final normalizedCity = input.city.trim();
    final normalizedLocality = input.locality.trim();
    final normalizedDescription = input.description.trim();
    final now = FieldValue.serverTimestamp();

    final payload = <String, dynamic>{
      'title': normalizedTitle,
      'price': input.price ?? 0,
      'city': normalizedCity,
      'city_lower': normalizedCity.toLowerCase(),
      'locality': normalizedLocality,
      'locality_lower': normalizedLocality.toLowerCase(),
      if (input.latitude != null) 'latitude': input.latitude,
      if (input.longitude != null) 'longitude': input.longitude,
      if (input.latitude != null || input.longitude != null)
        'searchLocation': {
          'latitude': input.latitude,
          'longitude': input.longitude,
        },
      'areaSqft': input.areaSqft,
      'description': normalizedDescription,
      'bhk': input.bhk ?? 0,
      'propertyCategory': input.propertyCategory,
      'listingType': input.listingType,
      'createdBy': (existingData['createdBy'] ?? user.uid).toString(),
      'uploadedBy': user.uid,
      'verificationStatus': verificationStatus,
      'listingStatus': listingStatus,
      'status': derivePropertyStatus(
        verificationStatus: verificationStatus,
        listingStatus: listingStatus,
      ),
      'imageUrls': finalImageUrls,
      'images': finalImageUrls,
      'createdAt': (existingSnapshot?.exists ?? false)
          ? (existingData['createdAt'] ?? now)
          : now,
      'updatedAt': now,
      'lastSellerActionAt': now,
      'draftSavedAt': verificationStatus == PropertyVerificationStatus.draft
          ? now
          : existingData['draftSavedAt'],
      'submittedAt': verificationStatus == PropertyVerificationStatus.pending
          ? (existingData['submittedAt'] ?? now)
          : existingData['submittedAt'],
      'resubmittedAt': incrementResubmissionCount
          ? now
          : existingData['resubmittedAt'],
      'resubmissionCount': incrementResubmissionCount
          ? ((existingData['resubmissionCount'] as num?)?.toInt() ?? 0) + 1
          : ((existingData['resubmissionCount'] as num?)?.toInt() ?? 0),
    };

    if (clearRejectionReason) {
      payload['rejectionReason'] = FieldValue.delete();
    }

    await docRef.set(payload, SetOptions(merge: true));

    await _logActivity(
      userId: user.uid,
      entityId: docRef.id,
      type: activityType,
      title: activityTitle,
      description: activityDescription,
    );

    return docRef.id;
  }

  Future<List<String>> _uploadNewImages({
    required String propertyId,
    required String ownerId,
    required List<File> images,
    required void Function(double progress) onUploadProgress,
  }) async {
    if (images.isEmpty) {
      onUploadProgress(1);
      return const <String>[];
    }

    return _imageUploadService.uploadPropertyImages(
      propertyId: propertyId,
      ownerId: ownerId,
      images: images,
      onProgress: onUploadProgress,
    );
  }

  Future<void> _logActivity({
    required String userId,
    required String entityId,
    required String type,
    required String title,
    required String description,
  }) async {
    try {
      await _db.collection('activities').add({
        'userId': userId,
        'type': type,
        'title': title,
        'description': description,
        'entityId': entityId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Activity logging should not make a successful property action appear failed.
    }
  }

  void _validateReadyForReview(PropertyUpsertInput input) {
    _validateInput(
      title: input.title,
      price: input.price ?? 0,
      city: input.city,
      bhk: input.bhk ?? 0,
      propertyCategory: input.propertyCategory,
      totalImages: input.existingImageUrls.length + input.newImages.length,
    );
  }

  void _validateInput({
    required String title,
    required int price,
    required String city,
    required int bhk,
    required String propertyCategory,
    required int totalImages,
  }) {
    if (title.trim().length < 3) {
      throw Exception('Title must be at least 3 characters');
    }
    if (price <= 0) {
      throw Exception('Price must be greater than zero');
    }
    if (city.trim().length < 2) {
      throw Exception('City is required');
    }
    if (_requiresBhk(propertyCategory) && (bhk <= 0 || bhk > 20)) {
      throw Exception('BHK value is invalid');
    }
    if (totalImages < 3) {
      throw Exception('Please add at least 3 images');
    }
    if (totalImages > 10) {
      throw Exception('Maximum 10 images allowed');
    }
  }

  bool _requiresBhk(String propertyCategory) {
    const bhkCategories = {
      'apartment',
      'house',
      'villa',
      'builder_floor',
      'flat_rent',
      'new_launch',
      'under_construction',
      'ready_to_move',
    };
    return bhkCategories.contains(propertyCategory);
  }
}
