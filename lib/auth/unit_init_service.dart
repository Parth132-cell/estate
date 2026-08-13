import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserInitService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> ensureUserDocument(User user) async {
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'uid': user.uid,
        'phone': user.phoneNumber ?? '',
        'name': '',
        'role': 'buyer',
        'roles': ['buyer'],
        'onboardingComplete': false,
        'isVerifiedBroker': false,
        'brokerApprovalStatus': null,
        'kycStatus': 'unverified',
        'canUploadProperty': true,
        'canHostLiveTour': false,
        'avgRating': 0.0,
        'reviewCount': 0,
        'preferences': {},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.set({
        'phone': user.phoneNumber ?? '',
        'lastLoginAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }
}
