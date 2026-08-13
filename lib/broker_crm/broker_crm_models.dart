import 'package:cloud_firestore/cloud_firestore.dart';

enum LeadStage {
  newLead,
  contacted,
  negotiation,
  closed;

  String get key {
    switch (this) {
      case LeadStage.newLead:
        return 'new';
      case LeadStage.contacted:
        return 'contacted';
      case LeadStage.negotiation:
        return 'negotiation';
      case LeadStage.closed:
        return 'closed';
    }
  }

  String get label {
    switch (this) {
      case LeadStage.newLead:
        return 'New';
      case LeadStage.contacted:
        return 'Contacted';
      case LeadStage.negotiation:
        return 'Negotiation';
      case LeadStage.closed:
        return 'Closed';
    }
  }

  static LeadStage fromRaw(String raw) {
    switch (raw) {
      case 'contacted':
        return LeadStage.contacted;
      case 'negotiation':
        return LeadStage.negotiation;
      case 'closed':
        return LeadStage.closed;
      case 'new':
      default:
        return LeadStage.newLead;
    }
  }
}

enum LeadPriority {
  low,
  medium,
  high;

  String get key {
    switch (this) {
      case LeadPriority.low:
        return 'low';
      case LeadPriority.medium:
        return 'medium';
      case LeadPriority.high:
        return 'high';
    }
  }

  String get label {
    switch (this) {
      case LeadPriority.low:
        return 'Low';
      case LeadPriority.medium:
        return 'Medium';
      case LeadPriority.high:
        return 'High';
    }
  }

  static LeadPriority fromRaw(String raw) {
    switch (raw) {
      case 'low':
        return LeadPriority.low;
      case 'high':
        return LeadPriority.high;
      case 'medium':
      default:
        return LeadPriority.medium;
    }
  }
}

class BrokerLeadNote {
  const BrokerLeadNote({
    required this.text,
    required this.createdAt,
    required this.createdBy,
  });

  final String text;
  final DateTime? createdAt;
  final String createdBy;

  factory BrokerLeadNote.fromMap(Map<String, dynamic> map) {
    return BrokerLeadNote(
      text: (map['text'] ?? '').toString(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      createdBy: (map['createdBy'] ?? '').toString(),
    );
  }
}

class BrokerCrmLead {
  const BrokerCrmLead({
    required this.id,
    required this.name,
    required this.phone,
    required this.status,
    required this.priority,
    required this.propertyId,
    required this.message,
    required this.chatRoomId,
    required this.followUpDate,
    required this.lastContacted,
    required this.createdAt,
    required this.updatedAt,
    required this.notes,
  });

  final String id;
  final String name;
  final String phone;
  final LeadStage status;
  final LeadPriority priority;
  final String propertyId;
  final String message;
  final String chatRoomId;
  final DateTime? followUpDate;
  final DateTime? lastContacted;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<BrokerLeadNote> notes;

  bool get hasNotes => notes.isNotEmpty;
  bool get isClosed => status == LeadStage.closed;

  factory BrokerCrmLead.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final noteMaps = (data['notes'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    return BrokerCrmLead(
      id: doc.id,
      name: (data['name'] ?? 'Unknown Lead').toString(),
      phone: (data['phone'] ?? '').toString(),
      status: LeadStage.fromRaw((data['status'] ?? 'new').toString()),
      priority: LeadPriority.fromRaw((data['priority'] ?? 'medium').toString()),
      propertyId: (data['propertyId'] ?? '').toString(),
      message: (data['message'] ?? '').toString(),
      chatRoomId: (data['chatRoomId'] ?? '').toString(),
      followUpDate: (data['followUpDate'] as Timestamp?)?.toDate(),
      lastContacted: (data['lastContacted'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      notes: noteMaps.map(BrokerLeadNote.fromMap).toList()
        ..sort((a, b) {
          final aMs = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final bMs = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return aMs.compareTo(bMs);
        }),
    );
  }
}

class BrokerLeadReminder {
  const BrokerLeadReminder({
    required this.leadId,
    required this.leadName,
    required this.stage,
    required this.priority,
    required this.dueAt,
  });

  final String leadId;
  final String leadName;
  final LeadStage stage;
  final LeadPriority priority;
  final DateTime dueAt;

  bool get isOverdue {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final dueDay = DateTime(dueAt.year, dueAt.month, dueAt.day);
    return dueDay.isBefore(startOfDay);
  }
}

class BrokerRecentNote {
  const BrokerRecentNote({
    required this.leadId,
    required this.leadName,
    required this.stage,
    required this.note,
  });

  final String leadId;
  final String leadName;
  final LeadStage stage;
  final BrokerLeadNote note;
}

class BrokerAnalyticsSnapshot {
  const BrokerAnalyticsSnapshot({
    required this.totalLeads,
    required this.stageCounts,
    required this.remindersDue,
    required this.upcomingReminders,
    required this.leadsWithNotes,
    required this.totalNotes,
    required this.contactRate,
    required this.negotiationRate,
    required this.closeRate,
    required this.activeDeals,
    required this.wonDeals,
    required this.rejectedDeals,
    required this.winRate,
  });

  final int totalLeads;
  final Map<LeadStage, int> stageCounts;
  final int remindersDue;
  final int upcomingReminders;
  final int leadsWithNotes;
  final int totalNotes;
  final int contactRate;
  final int negotiationRate;
  final int closeRate;
  final int activeDeals;
  final int wonDeals;
  final int rejectedDeals;
  final int winRate;

  int countFor(LeadStage stage) => stageCounts[stage] ?? 0;
}

class BrokerCrmDashboardData {
  const BrokerCrmDashboardData({
    required this.leads,
    required this.reminders,
    required this.recentNotes,
    required this.analytics,
  });

  final List<BrokerCrmLead> leads;
  final List<BrokerLeadReminder> reminders;
  final List<BrokerRecentNote> recentNotes;
  final BrokerAnalyticsSnapshot analytics;
}
