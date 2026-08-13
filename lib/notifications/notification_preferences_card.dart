import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'notification_models.dart';
import 'notification_service.dart';

class NotificationPreferencesCard extends StatefulWidget {
  const NotificationPreferencesCard({
    super.key,
    required this.userRef,
    required this.preferences,
  });

  final DocumentReference<Map<String, dynamic>> userRef;
  final NotificationPreferences preferences;

  @override
  State<NotificationPreferencesCard> createState() =>
      _NotificationPreferencesCardState();
}

class _NotificationPreferencesCardState
    extends State<NotificationPreferencesCard> {
  late NotificationPreferences _draft = widget.preferences;
  bool _saving = false;

  @override
  void didUpdateWidget(covariant NotificationPreferencesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_saving && oldWidget.preferences != widget.preferences) {
      _draft = widget.preferences;
    }
  }

  Future<void> _save(NotificationPreferences next) async {
    setState(() {
      _saving = true;
      _draft = next;
    });

    try {
      await AppNotificationService().updatePreferences(
        userRef: widget.userRef,
        preferences: next,
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF5F7FF),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.notifications_active_outlined,
                  color: Color(0xFF1D4ED8),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Notification Preferences',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                if (_saving)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose where alerts are delivered and which events matter to you.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            _PreferenceTile(
              title: 'Push notifications',
              subtitle: 'FCM alerts on this device',
              value: _draft.push,
              onChanged: (value) => _save(_draft.copyWith(push: value)),
            ),
            _PreferenceTile(
              title: 'Email alerts',
              subtitle: 'SendGrid delivery when configured',
              value: _draft.email,
              onChanged: (value) => _save(_draft.copyWith(email: value)),
            ),
            _PreferenceTile(
              title: 'SMS alerts',
              subtitle: 'Twilio delivery for critical updates',
              value: _draft.sms,
              onChanged: (value) => _save(_draft.copyWith(sms: value)),
            ),
            const Divider(height: 20),
            _PreferenceTile(
              title: 'Offer events',
              subtitle: 'New offers and counter-offers',
              value: _draft.offers,
              onChanged: (value) => _save(_draft.copyWith(offers: value)),
            ),
            _PreferenceTile(
              title: 'Message events',
              subtitle: 'Buyer and broker chat activity',
              value: _draft.messages,
              onChanged: (value) => _save(_draft.copyWith(messages: value)),
            ),
            _PreferenceTile(
              title: 'Payment events',
              subtitle: 'Escrow and payment verification updates',
              value: _draft.payments,
              onChanged: (value) => _save(_draft.copyWith(payments: value)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}
