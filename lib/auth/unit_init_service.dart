import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserInitService {
  final _db = FirebaseFirestore.instance;

  Future<void> ensureUserDocument() async {
    final user = FirebaseAuth.instance.currentUser!;
    final ref = _db.collection('users').doc(user.uid);
    await FirebaseAuth.instance.signOut();

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
  }
}
