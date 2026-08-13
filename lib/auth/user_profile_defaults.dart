import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Map<String, Object?> buildUserProfileSeed(User user) {
  return <String, Object?>{
    'name': '',
    'phone': user.phoneNumber ?? '',
    if ((user.email ?? '').isNotEmpty) 'email': user.email!,
    'role': 'user',
    'profileType': 'individual',
    'status': 'active',
    'kycStatus': 'unverified',
    'canUploadProperty': true,
    'canHostLiveTour': false,
    'isProfessional': false,
    'isVerifiedBroker': false,
    'ratingAverage': 0,
    'totalReviews': 0,
    'notificationPreferences': const {
      'push': true,
      'email': false,
      'sms': false,
      'offers': true,
      'messages': true,
      'payments': true,
    },
    'createdAt': FieldValue.serverTimestamp(),
  };
}
