import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PropertyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> submitProperty({
    required String title,
    required int price,
    required String city,
    required int bhk,
    required String listingType,
  }) async {
    final user = FirebaseAuth.instance.currentUser!;
    final docRef = _db.collection('properties').doc();

    print('STEP 1: Creating property document');

    // 1️⃣ Create property WITHOUT images
    await docRef.set({
      'title': title,
      'price': price,
      'city': city,
      'city_lower': city.toLowerCase(),
      'bhk': bhk,
      'listingType': listingType,
      'uploadedBy': user.uid,
      'verificationStatus': 'pending',
      'images': [], // placeholder
      'createdAt': FieldValue.serverTimestamp(),
    });

    print('STEP 2: Property document created');

    // 2️⃣ Create activity
    print('STEP 3: Creating activity');
    await _db.collection('activities').add({
      'userId': user.uid,
      'type': 'property_submitted',
      'title': 'Property submitted',
      'description': 'Your property is under review',
      'entityId': docRef.id,
      'createdAt': FieldValue.serverTimestamp(),
    });

    print('STEP 4: Activity created');
  }
}
