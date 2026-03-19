import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class SubmitPropertyService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  Future<void> submit({
    required String title,
    required double price,
    required String city,
    required int bhk,
    required String listingType,
    required List<File> images,
  }) async {
    List<String> imageUrls = [];

    // Upload each image
    for (File image in images) {
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();

      final ref = _storage.ref().child('property_images/$fileName.jpg');

      await ref.putFile(image);

      final url = await ref.getDownloadURL();

      imageUrls.add(url);
    }

    // Save property with image URLs
    await _db.collection('properties').add({
      'title': title,
      'price': price,
      'city': city,
      'bhk': bhk,
      'listingType': listingType,
      'images': imageUrls,
      'verificationStatus': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
