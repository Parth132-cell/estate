import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationPreferences {
  const NotificationPreferences({
    this.push = true,
    this.email = false,
    this.sms = false,
    this.offers = true,
    this.messages = true,
    this.payments = true,
  });

  final bool push;
  final bool email;
  final bool sms;
  final bool offers;
  final bool messages;
  final bool payments;

  factory NotificationPreferences.fromUserData(Map<String, dynamic>? data) {
    final raw = (data?['notificationPreferences'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    return NotificationPreferences(
      push: raw['push'] != false,
      email: raw['email'] == true,
      sms: raw['sms'] == true,
      offers: raw['offers'] != false,
      messages: raw['messages'] != false,
      payments: raw['payments'] != false,
    );
  }

  NotificationPreferences copyWith({
    bool? push,
    bool? email,
    bool? sms,
    bool? offers,
    bool? messages,
    bool? payments,
  }) {
    return NotificationPreferences(
      push: push ?? this.push,
      email: email ?? this.email,
      sms: sms ?? this.sms,
      offers: offers ?? this.offers,
      messages: messages ?? this.messages,
      payments: payments ?? this.payments,
    );
  }

  Map<String, bool> toMap() {
    return <String, bool>{
      'push': push,
      'email': email,
      'sms': sms,
      'offers': offers,
      'messages': messages,
      'payments': payments,
    };
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.metadata,
    required this.channels,
    required this.priority,
    required this.read,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String type;
  final String title;
  final String message;
  final Map<String, dynamic> metadata;
  final List<String> channels;
  final String priority;
  final bool read;
  final DateTime? createdAt;

  factory AppNotification.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawChannels = data['channels'];
    final singleChannel = (data['channel'] ?? '').toString().trim();

    return AppNotification(
      id: doc.id,
      userId: (data['userId'] ?? '').toString(),
      type: (data['type'] ?? '').toString(),
      title: (data['title'] ?? 'Notification').toString(),
      message: (data['message'] ?? '').toString(),
      metadata: (data['metadata'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      channels: rawChannels is Iterable
          ? rawChannels.map((item) => item.toString()).where((item) => item.isNotEmpty).toList()
          : singleChannel.isEmpty
              ? const <String>['in_app']
              : <String>[singleChannel],
      priority: (data['priority'] ?? 'normal').toString(),
      read: data['read'] == true,
      createdAt: switch (data['createdAt']) {
        final Timestamp timestamp => timestamp.toDate(),
        _ => null,
      },
    );
  }
}
