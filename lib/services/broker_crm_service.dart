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

      int highPriority = 0;
      int mediumPriority = 0;
      int lowPriority = 0;
      int newLeads = 0;
      int contacted = 0;
      int closed = 0;
      int remindersDue = 0;
      int leadsWithNotes = 0;

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      for (final doc in leads) {
        final data = doc.data();
        final priority = (data['priority'] ?? '').toString();
        final status = (data['status'] ?? '').toString();
        final followUp = (data['followUpDate'] as Timestamp?)?.toDate();
        final notes = data['notes'] as List<dynamic>? ?? [];

        if (priority == 'high') highPriority++;
        if (priority == 'medium') mediumPriority++;
        if (priority == 'low') lowPriority++;

        if (status == 'new') newLeads++;
        if (status == 'contacted') contacted++;
        if (status == 'closed') closed++;

        if (followUp != null && !followUp.isAfter(startOfDay) && status != 'closed') {
          remindersDue++;
        }

        if (notes.isNotEmpty) leadsWithNotes++;
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
      final closeRate = totalLeads == 0 ? 0 : ((closed * 100) / totalLeads).round();
      final winRate = deals.isEmpty ? 0 : ((wonDeals * 100) / deals.length).round();

      return {
        'totalLeads': totalLeads,
        'highPriority': highPriority,
        'mediumPriority': mediumPriority,
        'lowPriority': lowPriority,
        'newLeads': newLeads,
        'contacted': contacted,
        'closed': closed,
        'leadsWithNotes': leadsWithNotes,
        'remindersDue': remindersDue,
        'contactedRate': contactedRate,
        'closeRate': closeRate,
        'activeDeals': activeDeals,
        'wonDeals': wonDeals,
        'rejectedDeals': rejectedDeals,
        'winRate': winRate,
      };
    });
  }
}
