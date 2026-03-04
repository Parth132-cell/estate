import 'package:cloud_firestore/cloud_firestore.dart';

class BrokerCrmService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<Map<String, int>> brokerKpis(String brokerId) {
    final leadsStream = _db
        .collection('leads')
        .where('brokerId', isEqualTo: brokerId)
        .snapshots();

    return leadsStream.asyncMap((leadSnap) async {
      final dealSnap = await _db
          .collection('deals')
          .where('brokerId', isEqualTo: brokerId)
          .get();

      final leads = leadSnap.docs;
      final deals = dealSnap.docs;

      int hotLeads = 0;
      int contacted = 0;
      for (final doc in leads) {
        final data = doc.data();
        if ((data['priority'] ?? '') == 'hot') hotLeads++;
        if ((data['status'] ?? '') == 'contacted') contacted++;
      }

      int activeDeals = 0;
      int wonDeals = 0;
      for (final doc in deals) {
        final data = doc.data();
        final status = (data['status'] ?? '').toString();
        if (status == 'accepted' || status == 'counter' || status == 'pending') {
          activeDeals++;
        }
        if (status == 'completed' || status == 'released') {
          wonDeals++;
        }
      }

      return {
        'totalLeads': leads.length,
        'hotLeads': hotLeads,
        'contacted': contacted,
        'activeDeals': activeDeals,
        'wonDeals': wonDeals,
      };
    });
  }
}
