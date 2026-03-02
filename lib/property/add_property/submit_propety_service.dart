import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubmitPropertyService {
  final _db = FirebaseFirestore.instance;

  Future<void> submit({
    required String title,
    required double price,
    required String city,
    required int bhk,
    required String listingType,
    required List<File> images,
  }) async {
    // Image upload → later (Firebase Storage / S3)

    await _db.collection('properties').add({
      'title': title,
      'price': price,
      'city': city,
      'bhk': bhk,
      'listingType': listingType,
      'verificationStatus': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
