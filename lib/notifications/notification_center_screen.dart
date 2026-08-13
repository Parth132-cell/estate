import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'notification_models.dart';
import 'notification_service.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final _service = AppNotificationService();
  bool _showUnreadOnly = false;

  IconData _iconForType(String type) {
    if (type.startsWith('offer') || type == 'counter_offer') {
      return Icons.local_offer_outlined;
    }
    if (type == 'chat_message') {
      return Icons.chat_bubble_outline;
    }
    if (type.startsWith('payment')) {
      return Icons.account_balance_wallet_outlined;
    }
    return Icons.notifications_none_rounded;
  }

  Color _colorForType(BuildContext context, String type) {
    if (type.startsWith('payment_success')) return Colors.green.shade700;
    if (type.startsWith('payment_failed')) return Colors.red.shade700;
    if (type == 'chat_message') return Colors.blue.shade700;
    return Theme.of(context).colorScheme.primary;
  }

  String _channelLabel(String channel) {
    return switch (channel) {
      'push' => 'Push',
      'email' => 'Email',
      'sms' => 'SMS',
      'in_app' => 'In-app',
      _ => channel.replaceAll('_', ' '),
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Please sign in to view notifications')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => _service.markAllRead(),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _service.watchNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Unable to load notifications: ${snapshot.error}'),
            );
          }

          final notifications = snapshot.data ?? const <AppNotification>[];
          final unreadCount = notifications.where((item) => !item.read).length;
          final visibleItems = _showUnreadOnly
              ? notifications.where((item) => !item.read).toList(growable: false)
              : notifications;

          if (notifications.isEmpty) {
            return const Center(child: Text('No notifications yet'));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: 'Unread',
                        value: unreadCount.toString(),
                        accent: const Color(0xFF1D4ED8),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryCard(
                        label: 'Total',
                        value: notifications.length.toString(),
                        accent: const Color(0xFF0F766E),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(value: false, label: Text('All')),
                      ButtonSegment<bool>(value: true, label: Text('Unread')),
                    ],
                    selected: {_showUnreadOnly},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _showUnreadOnly = selection.first;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: visibleItems.isEmpty
                    ? const Center(
                        child: Text('No unread notifications right now'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: visibleItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = visibleItems[index];
                          final createdText = item.createdAt == null
                              ? ''
                              : _formatDate(item.createdAt!);

                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _service.markRead(item.id),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: item.read
                                    ? Colors.white
                                    : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: item.read
                                      ? Colors.black12
                                      : Colors.blue.shade100,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: _colorForType(
                                      context,
                                      item.type,
                                    ).withOpacity(0.12),
                                    foregroundColor: _colorForType(
                                      context,
                                      item.type,
                                    ),
                                    child: Icon(_iconForType(item.type)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.title,
                                                style: TextStyle(
                                                  fontWeight: item.read
                                                      ? FontWeight.w600
                                                      : FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            if (!item.read)
                                              Container(
                                                width: 9,
                                                height: 9,
                                                decoration: const BoxDecoration(
                                                  color: Colors.blue,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.message,
                                          style: const TextStyle(
                                            color: Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: item.channels
                                              .map(
                                                (channel) => Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 5,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFF5F7FF),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          999,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    _channelLabel(channel),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.black54,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(growable: false),
                                        ),
                                        if (createdText.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          Text(
                                            createdText,
                                            style: const TextStyle(
                                              color: Colors.black45,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}
