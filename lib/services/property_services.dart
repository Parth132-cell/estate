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
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final docRef = _db.collection('properties').doc();

    await user.reload();
    await user.getIdToken(true);

    // 1️⃣ Upload images and get download urls
    final imageUrls = await _imageUploadService.uploadPropertyImages(
      propertyId: docRef.id,
      images: images,
    );

    if (imageUrls.isEmpty) {
      throw Exception('Image upload failed. No image URLs were created');
    }

    // 2️⃣ Create property with image urls
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
      'uploadedBy': user.uid,
      'verificationStatus': 'pending',
      'images': imageUrls,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 3️⃣ Create activity
    await _db.collection('activities').add({
      'userId': user.uid,
      'type': 'property_submitted',
      'title': 'Property submitted',
      'description': 'Your property is under review',
      'entityId': docRef.id,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
