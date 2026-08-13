import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/broker_crm/broker_crm_models.dart';

class BrokerCrmService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<BrokerCrmDashboardData> watchDashboard(String brokerId) {
    final leadsStream = _db
        .collection('leads')
        .where('brokerId', isEqualTo: brokerId)
        .snapshots();

    return leadsStream.asyncMap((leadSnap) async {
      final dealSnap = await _db
          .collection('offers')
          .where('sellerId', isEqualTo: brokerId)
          .get();

      final leads = leadSnap.docs.map(BrokerCrmLead.fromDocument).toList()
        ..sort((a, b) {
          final aMs = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final bMs = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return bMs.compareTo(aMs);
        });
      final deals = dealSnap.docs;

      final stageCounts = {
        for (final stage in LeadStage.values) stage: 0,
      };
      final reminders = <BrokerLeadReminder>[];
      final recentNotes = <BrokerRecentNote>[];
      int totalNotes = 0;
      int remindersDue = 0;
      int upcomingReminders = 0;
      int leadsWithNotes = 0;

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final upcomingThreshold = startOfDay.add(const Duration(days: 3));

      for (final lead in leads) {
        stageCounts[lead.status] = (stageCounts[lead.status] ?? 0) + 1;
        totalNotes += lead.notes.length;
        if (lead.notes.isNotEmpty) {
          leadsWithNotes++;
          for (final note in lead.notes) {
            recentNotes.add(
              BrokerRecentNote(
                leadId: lead.id,
                leadName: lead.name,
                stage: lead.status,
                note: note,
              ),
            );
          }
        }

        final followUp = lead.followUpDate;
        if (followUp != null && !followUp.isAfter(startOfDay) && !lead.isClosed) {
          remindersDue++;
          reminders.add(
            BrokerLeadReminder(
              leadId: lead.id,
              leadName: lead.name,
              stage: lead.status,
              priority: lead.priority,
              dueAt: followUp,
            ),
          );
        } else if (followUp != null &&
            !followUp.isAfter(upcomingThreshold) &&
            !lead.isClosed) {
          upcomingReminders++;
          reminders.add(
            BrokerLeadReminder(
              leadId: lead.id,
              leadName: lead.name,
              stage: lead.status,
              priority: lead.priority,
              dueAt: followUp,
            ),
          );
        }
      }

      reminders.sort((a, b) => a.dueAt.compareTo(b.dueAt));
      recentNotes.sort((a, b) {
        final aMs = a.note.createdAt?.millisecondsSinceEpoch ?? 0;
        final bMs = b.note.createdAt?.millisecondsSinceEpoch ?? 0;
        return bMs.compareTo(aMs);
      });

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
      final engagedLeads = (stageCounts[LeadStage.contacted] ?? 0) +
          (stageCounts[LeadStage.negotiation] ?? 0) +
          (stageCounts[LeadStage.closed] ?? 0);
      final contactedRate =
          totalLeads == 0 ? 0 : ((engagedLeads * 100) / totalLeads).round();
      final negotiationRate = totalLeads == 0
          ? 0
          : (((stageCounts[LeadStage.negotiation] ?? 0) * 100) / totalLeads)
                .round();
      final closeRate = totalLeads == 0
          ? 0
          : (((stageCounts[LeadStage.closed] ?? 0) * 100) / totalLeads).round();
      final winRate = deals.isEmpty ? 0 : ((wonDeals * 100) / deals.length).round();

      return BrokerCrmDashboardData(
        leads: leads,
        reminders: reminders.take(8).toList(),
        recentNotes: recentNotes.take(8).toList(),
        analytics: BrokerAnalyticsSnapshot(
          totalLeads: totalLeads,
          stageCounts: stageCounts,
          remindersDue: remindersDue,
          upcomingReminders: upcomingReminders,
          leadsWithNotes: leadsWithNotes,
          totalNotes: totalNotes,
          contactRate: contactedRate,
          negotiationRate: negotiationRate,
          closeRate: closeRate,
          activeDeals: activeDeals,
          wonDeals: wonDeals,
          rejectedDeals: rejectedDeals,
          winRate: winRate,
        ),
      );
    });
  }

  Future<void> moveLeadToStage({
    required String leadId,
    required LeadStage stage,
  }) async {
    await _db.collection('leads').doc(leadId).update({
      'status': stage.key,
      'updatedAt': FieldValue.serverTimestamp(),
      if (stage == LeadStage.contacted || stage == LeadStage.negotiation)
        'lastContacted': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addLeadNote({
    required String leadId,
    required String note,
    required String userId,
  }) async {
    if (note.trim().isEmpty) return;

    await _db.collection('leads').doc(leadId).update({
      'notes': FieldValue.arrayUnion([
        {
          'text': note.trim(),
          'createdAt': Timestamp.now(),
          'createdBy': userId,
        },
      ]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> scheduleReminder({
    required String leadId,
    required DateTime reminderAt,
  }) async {
    await _db.collection('leads').doc(leadId).update({
      'followUpDate': Timestamp.fromDate(reminderAt),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
