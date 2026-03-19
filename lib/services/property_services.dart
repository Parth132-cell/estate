import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../property/image_upload_service.dart';

class PropertyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ImageUploadService _imageUploadService = ImageUploadService();

  Future<void> submitProperty({
    required String title,
    required int price,
    required String city,
    String? locality,
    int? areaSqft,
    String? description,
    required int bhk,
    required String listingType,
    required List<File> images,
    required void Function(double progress) onUploadProgress,
  }) async {
    _validateInput(
      title: title,
      price: price,
      city: city,
      bhk: bhk,
      images: images,
    );

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Only authenticated users can submit properties');
    }

    final docRef = _db.collection('properties').doc();

    await user.reload();
    await user.getIdToken(true);

    final imageUrls = await _imageUploadService.uploadPropertyImages(
      propertyId: docRef.id,
      images: images,
      onProgress: onUploadProgress,
    );

    if (imageUrls.isEmpty) {
      throw Exception('Image upload failed. No image URLs were created');
    }

    await docRef.set({
      'title': title,
      'price': price,
      'city': city,
      'city_lower': city.toLowerCase(),
      'locality': locality,
      'areaSqft': areaSqft,
      'description': description,
      'bhk': bhk,
      'listingType': listingType,
      'createdBy': user.uid,
      'uploadedBy': user.uid,
      'status': 'pending',
      'verificationStatus': 'pending',
      'imageUrls': imageUrls,
      'images': imageUrls,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('activities').add({
      'userId': user.uid,
      'type': 'property_submitted',
      'title': 'Property submitted',
      'description': 'Your property is under review',
      'entityId': docRef.id,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void _validateInput({
    required String title,
    required int price,
    required String city,
    required int bhk,
    required List<File> images,
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
    if (bhk <= 0 || bhk > 20) {
      throw Exception('BHK value is invalid');
    }
    if (images.length < 3) {
      throw Exception('Please add at least 3 images');
    }
    if (images.length > 10) {
      throw Exception('Maximum 10 images allowed');
    }
  }
}
