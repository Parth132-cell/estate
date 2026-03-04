import 'package:cloud_firestore/cloud_firestore.dart';

class AiRecommendationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Phase-3 stub: returns ranked approved properties using lightweight scoring.
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> recommendations() {
    return _db
        .collection('properties')
        .where('verificationStatus', isEqualTo: 'approved')
        .limit(20)
        .snapshots()
        .map((snap) {
      final docs = [...snap.docs];
      docs.sort((a, b) {
        final aData = a.data();
        final bData = b.data();
        final aFeatured = aData['isFeatured'] == true ? 1 : 0;
        final bFeatured = bData['isFeatured'] == true ? 1 : 0;
        if (aFeatured != bFeatured) return bFeatured.compareTo(aFeatured);

        final aPrice = (aData['price'] as num?)?.toInt() ?? 0;
        final bPrice = (bData['price'] as num?)?.toInt() ?? 0;
        return aPrice.compareTo(bPrice);
      });
      return docs;
    });
  }
}
