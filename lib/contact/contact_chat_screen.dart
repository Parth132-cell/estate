import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ContactChatScreen extends StatefulWidget {
  final String brokerId;
  final String propertyId;
  final String propertyTitle;

  const ContactChatScreen({
    super.key,
    required this.brokerId,
    required this.propertyId,
    required this.propertyTitle,
  });

  @override
  State<ContactChatScreen> createState() => _ContactChatScreenState();
}

class _ContactChatScreenState extends State<ContactChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  Map<String, dynamic>? _brokerData;
  Map<String, dynamic>? _propertyData;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // Chat room ID is deterministic — same for same buyer+broker+property
  String get _chatRoomId =>
      'chat_lead_${_uid}_${widget.brokerId}_${widget.propertyId}';

  @override
  void initState() {
    super.initState();
    _initChatRoom();
    _loadProfiles();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _initChatRoom() async {
    final ref = FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(_chatRoomId);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'buyerId': _uid,
        'brokerId': widget.brokerId,
        'propertyId': widget.propertyId,
        'propertyTitle': widget.propertyTitle,
        'lastMessageText': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadBuyer': 0,
        'unreadBroker': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    // Mark messages as read
    await ref.update({
      _uid == (snap.data()?['buyerId']) ? 'unreadBuyer' : 'unreadBroker': 0,
    });
  }

  Future<void> _loadProfiles() async {
    try {
      final brokerSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.brokerId)
          .get();
      final propSnap = await FirebaseFirestore.instance
          .collection('properties')
          .doc(widget.propertyId)
          .get();
      if (mounted) {
        setState(() {
          _brokerData = brokerSnap.data();
          _propertyData = propSnap.data();
        });
      }
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    // Block phone numbers — privacy enforcement
    if (_containsPhone(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Phone numbers are not allowed in chat. Use the in-app tools to connect.',
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _msgCtrl.clear();
    setState(() => _sending = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final msgRef = FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(_chatRoomId)
          .collection('messages')
          .doc();
      final roomRef = FirebaseFirestore.instance
          .collection('chat_rooms')
          .doc(_chatRoomId);

      batch.set(msgRef, {
        'text': text,
        'senderId': _uid,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      // Update last message + unread count for recipient
      final isbuyer = _uid != widget.brokerId;
      batch.update(roomRef, {
        'lastMessageText': text,
        'lastMessageAt': FieldValue.serverTimestamp(),
        if (isbuyer) 'unreadBroker': FieldValue.increment(1),
        if (!isbuyer) 'unreadBuyer': FieldValue.increment(1),
      });

      await batch.commit();

      // Scroll to bottom
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool _containsPhone(String text) {
    // Block 10-digit Indian mobile numbers
    return RegExp(r'[6-9]\d{9}').hasMatch(text.replaceAll(' ', '')) ||
        RegExp(r'\+91\d{10}').hasMatch(text.replaceAll(' ', ''));
  }

  @override
  Widget build(BuildContext context) {
    final brokerName = (_brokerData?['name'] ?? 'Agent').toString();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primarySoft,
              child: Text(
                brokerName.isNotEmpty ? brokerName[0].toUpperCase() : 'A',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    brokerName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Text(
                    'Via EstateX secure chat',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Privacy badge — no call button
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 12,
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 4),
                Text(
                  'Secure',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Property context card
          if (_propertyData != null)
            _PropertyContextBanner(data: _propertyData!),

          // Privacy notice
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFFFFBEB),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Colors.amber.shade700,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Contact details are hidden for your privacy. Communicate through EstateX only.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('chat_rooms')
                  .doc(_chatRoomId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final msgs = snap.data?.docs ?? [];
                if (msgs.isEmpty) {
                  return const _EmptyChat();
                }
                return ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final m = msgs[i].data();
                    final isMe = m['senderId'] == _uid;
                    final at = (m['createdAt'] as Timestamp?)?.toDate();
                    return _MessageBubble(
                      text: m['text']?.toString() ?? '',
                      isMe: isMe,
                      time: at,
                    );
                  },
                );
              },
            ),
          ),

          // Input bar
          _InputBar(controller: _msgCtrl, sending: _sending, onSend: _send),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// PROPERTY CONTEXT BANNER
// ─────────────────────────────────────────

class _PropertyContextBanner extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PropertyContextBanner({required this.data});

  @override
  Widget build(BuildContext context) {
    final images = (data['images'] as List? ?? [])
        .map((e) => e.toString())
        .toList();
    final title = (data['title'] ?? '').toString();
    final city = (data['city'] ?? '').toString();
    final price = (data['price'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: images.isNotEmpty
                ? Image.network(
                    images.first,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  city,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (price > 0)
            Text(
              price >= 10000000
                  ? '₹${(price / 10000000).toStringAsFixed(1)}Cr'
                  : '₹${(price / 100000).toStringAsFixed(0)}L',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 48,
    height: 48,
    color: Colors.grey.shade200,
    child: const Icon(Icons.home_outlined, color: Colors.grey, size: 20),
  );
}

// ─────────────────────────────────────────
// MESSAGE BUBBLE
// ─────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final DateTime? time;

  const _MessageBubble({required this.text, required this.isMe, this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primarySoft,
              child: const Icon(
                Icons.person,
                size: 16,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      color: isMe ? Colors.white : AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  if (time != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('h:mm a').format(time!),
                      style: TextStyle(
                        fontSize: 10,
                        color: isMe ? Colors.white70 : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// INPUT BAR
// ─────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Type a message…',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: sending ? null : onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: sending ? Colors.grey.shade300 : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: sending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// EMPTY CHAT
// ─────────────────────────────────────────

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_outlined,
                color: AppColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Start the conversation',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask about the property, schedule a visit, or discuss pricing — all through EstateX securely.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
