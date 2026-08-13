import 'package:cloud_firestore/cloud_firestore.dart';

class CoBrokerService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> assignCoBroker({
    required String offerId, // was: dealId — renamed to match screen
    required String coBrokerId,
    required int splitPercent,
  }) async {
    await _db.collection('offers').doc(offerId).update({
      'coBrokerId': coBrokerId,
      'coBrokerSplitPercent': splitPercent,
      'coBrokerStatus':
          'pending', // was: 'invited' — screen checks for 'pending'
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // was: respondToInvite(dealId, accepted: bool)
  // screen calls: respondToAssignment(offerId, response: 'accepted'|'declined')
  Future<void> respondToAssignment({
    required String offerId,
    required String response, // 'accepted' | 'declined'
  }) async {
    const allowed = {'accepted', 'declined'};
    if (!allowed.contains(response)) {
      throw ArgumentError(
        'Invalid response: $response. Must be accepted or declined.',
      );
    }

    await _db.collection('offers').doc(offerId).update({
      'coBrokerStatus': response, // was: accepted ? 'accepted' : 'rejected'
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
