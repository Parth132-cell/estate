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
      int warmLeads = 0;
      int contacted = 0;
      int followUpsSet = 0;
      for (final doc in leads) {
        final data = doc.data();
        final priority = (data['priority'] ?? '').toString();
        final status = (data['status'] ?? '').toString();
        if (priority == 'hot') hotLeads++;
        if (priority == 'warm') warmLeads++;
        if (status == 'contacted') contacted++;
        if (data['nextFollowUp'] != null) followUpsSet++;
      }

      int activeDeals = 0;
      int wonDeals = 0;
      int rejectedDeals = 0;
      for (final doc in deals) {
        final data = doc.data();
        final status = (data['status'] ?? '').toString();
        if (status == 'accepted' || status == 'counter' || status == 'pending') {
          activeDeals++;
        }
        if (status == 'completed' || status == 'released') {
          wonDeals++;
        }
        if (status == 'rejected') {
          rejectedDeals++;
        }
      }

      final totalLeads = leads.length;
      final contactedRate = totalLeads == 0 ? 0 : ((contacted * 100) / totalLeads).round();
      final winRate = deals.isEmpty ? 0 : ((wonDeals * 100) / deals.length).round();

      return {
        'totalLeads': totalLeads,
        'hotLeads': hotLeads,
        'warmLeads': warmLeads,
        'contacted': contacted,
        'followUpsSet': followUpsSet,
        'contactedRate': contactedRate,
        'activeDeals': activeDeals,
        'wonDeals': wonDeals,
        'rejectedDeals': rejectedDeals,
        'winRate': winRate,
      };
    });
  }
}
