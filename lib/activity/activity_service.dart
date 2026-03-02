import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> getUserActivities(String userId) {
    return _db
        .collection('activities')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
