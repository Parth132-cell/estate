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

      final data = snap.data() ?? <String, dynamic>{};

      if (!snap.exists) {
        await ref.set({
          'name': '',
          'phone': user.phoneNumber ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'role': 'user',
          'kycStatus': 'unverified',
          'canUploadProperty': true,
          'canHostLiveTour': false,
          'isProfessional': false,
        }, SetOptions(merge: true));
        return;
      }

      final updates = <String, dynamic>{};
      if ((data['name'] ?? '').toString().isEmpty) updates['name'] = '';
      if ((data['phone'] ?? '').toString().isEmpty) {
        updates['phone'] = user.phoneNumber ?? '';
      }
      if ((data['role'] ?? '').toString().isEmpty) updates['role'] = 'user';
      if (data['createdAt'] == null) updates['createdAt'] = FieldValue.serverTimestamp();

      if (updates.isNotEmpty) {
        await ref.set(updates, SetOptions(merge: true));
      }
    } on FirebaseException catch (e) {
      // Allow app navigation even if Firestore rules are not ready.
      if (e.code != 'permission-denied') rethrow;
      print('UserInitService permission error: $e');
    }
  }
}
