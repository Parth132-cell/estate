import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserInitService {
  final _db = FirebaseFirestore.instance;

  Future<void> ensureUserDocument() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = _db.collection('users').doc(user.uid);

    try {
      final snap = await ref.get();

      if (!snap.exists) {
        await ref.set({
          'phone': user.phoneNumber,
          'createdAt': FieldValue.serverTimestamp(),
          'kycStatus': 'unverified',
          'canUploadProperty': true,
          'canHostLiveTour': false,
          'isProfessional': false,
        });
      }
    } on FirebaseException catch (e) {
      // Allow app navigation even if Firestore rules are not ready.
      if (e.code != 'permission-denied') rethrow;
      print('UserInitService permission error: $e');
    }
  }
}
