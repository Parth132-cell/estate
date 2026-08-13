import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ContactSession {
  const ContactSession({
    required this.leadId,
    required this.chatRoomId,
    required this.buyerId,
    required this.brokerId,
    required this.maskedPhoneAlias,
    required this.buyerPhoneMasked,
    required this.brokerPhoneMasked,
    this.propertyId,
    this.propertyTitle,
    this.callbackStatus = 'not_requested',
  });

  final String leadId;
  final String chatRoomId;
  final String buyerId;
  final String brokerId;
  final String maskedPhoneAlias;
  final String buyerPhoneMasked;
  final String brokerPhoneMasked;
  final String? propertyId;
  final String? propertyTitle;
  final String callbackStatus;

  factory ContactSession.fromLeadDocument(
    String leadId,
    Map<String, dynamic> data,
  ) {
    final chatRoomId = (data['chatRoomId'] ?? 'chat_$leadId').toString();
    return ContactSession(
      leadId: leadId,
      chatRoomId: chatRoomId,
      buyerId: (data['buyerId'] ?? '').toString(),
      brokerId: (data['brokerId'] ?? '').toString(),
      propertyId: data['propertyId']?.toString(),
      propertyTitle: data['propertyTitle']?.toString(),
      maskedPhoneAlias: (data['maskedPhoneAlias'] ?? '').toString(),
      buyerPhoneMasked: (data['buyerPhoneMasked'] ?? data['phone'] ?? '').toString(),
      brokerPhoneMasked: (data['brokerPhoneMasked'] ?? '').toString(),
      callbackStatus: (data['callbackStatus'] ?? 'not_requested').toString(),
    );
  }
}

class ContactService {
  ContactService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    return user.uid;
  }

  Future<ContactSession> ensureBuyerContactSession({
    required String brokerId,
    String? propertyId,
    String? propertyTitle,
  }) async {
    final buyerId = _uid;
    final normalizedBrokerId = brokerId.trim();
    if (normalizedBrokerId.isEmpty) {
      throw Exception('Broker details unavailable');
    }
    if (buyerId == normalizedBrokerId) {
      throw Exception('You cannot start a contact thread with yourself');
    }

    final buyerSnap = await _db.collection('users').doc(buyerId).get();
    final brokerSnap = await _db.collection('users').doc(normalizedBrokerId).get();
    final buyerData = buyerSnap.data() ?? <String, dynamic>{};
    final brokerData = brokerSnap.data() ?? <String, dynamic>{};

    final safePropertyId = propertyId?.trim().isNotEmpty == true
        ? propertyId!.trim()
        : null;
    final propertyKey = safePropertyId ?? 'general';
    final leadId = 'lead_${buyerId}_${normalizedBrokerId}_$propertyKey';
    final chatRoomId = 'chat_$leadId';
    final maskedAlias = _buildMaskedAlias(leadId);
    final buyerName = _displayName(
      fallback: _auth.currentUser?.displayName,
      data: buyerData,
      defaultValue: 'Interested Buyer',
    );
    final brokerName = _displayName(
      fallback: null,
      data: brokerData,
      defaultValue: 'Broker',
    );
    final buyerPhoneMasked = _maskPhone(
      (buyerData['phone'] ?? _auth.currentUser?.phoneNumber ?? '').toString(),
    );
    final brokerPhoneMasked = _maskPhone(
      (brokerData['phone'] ?? '').toString(),
    );

    final leadRef = _db.collection('leads').doc(leadId);
    final roomRef = _db.collection('chat_rooms').doc(chatRoomId);
    var createdLead = false;
    final leadCreateData = <String, dynamic>{
      'propertyId': safePropertyId,
      'propertyTitle': propertyTitle?.trim().isNotEmpty == true
          ? propertyTitle!.trim()
          : '',
      'brokerId': normalizedBrokerId,
      'buyerId': buyerId,
      'name': buyerName,
      'phone': buyerPhoneMasked,
      'message': '',
      'status': 'new',
      'priority': 'high',
      'notes': const <dynamic>[],
      'chatRoomId': chatRoomId,
      'maskedPhoneAlias': maskedAlias,
      'buyerPhoneMasked': buyerPhoneMasked,
      'brokerPhoneMasked': brokerPhoneMasked,
      'contactSource': 'contact_cta',
      'callbackRequested': false,
      'callbackStatus': 'not_requested',
      'unreadBuyerCount': 0,
      'unreadBrokerCount': 0,
      'lastMessageText': '',
      'lastMessageAt': null,
      'lastMessageBy': null,
      'contactClicks': 1,
      'lastIntentAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final roomCreateData = <String, dynamic>{
      'leadId': leadId,
      'propertyId': safePropertyId,
      'propertyTitle': propertyTitle?.trim().isNotEmpty == true
          ? propertyTitle!.trim()
          : '',
      'buyerId': buyerId,
      'brokerId': normalizedBrokerId,
      'participantIds': [buyerId, normalizedBrokerId],
      'buyerName': buyerName,
      'brokerName': brokerName,
      'maskedPhoneAlias': maskedAlias,
      'buyerPhoneMasked': buyerPhoneMasked,
      'brokerPhoneMasked': brokerPhoneMasked,
      'callbackRequested': false,
      'callbackStatus': 'not_requested',
      'lastMessageText': '',
      'lastMessageAt': null,
      'lastMessageBy': null,
      'unreadBuyerCount': 0,
      'unreadBrokerCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await _db.runTransaction((txn) async {
        final leadSnap = await txn.get(leadRef);
        final leadData = leadSnap.data() ?? <String, dynamic>{};
        final roomSnap = await txn.get(roomRef);
        final roomData = roomSnap.data() ?? <String, dynamic>{};

        createdLead = !leadSnap.exists;

        txn.set(leadRef, {
          'propertyId': safePropertyId,
          'propertyTitle':
              propertyTitle?.trim().isNotEmpty == true
                  ? propertyTitle!.trim()
                  : (leadData['propertyTitle'] ?? ''),
          'brokerId': normalizedBrokerId,
          'buyerId': buyerId,
          'name': buyerName,
          'phone': buyerPhoneMasked,
          'message': (leadData['message'] ?? '').toString(),
          'status': (leadData['status'] ?? 'new').toString(),
          'priority': (leadData['priority'] ?? 'high').toString(),
          'followUpDate': leadData['followUpDate'],
          'lastContacted': leadData['lastContacted'],
          'notes': leadData['notes'] ?? const <dynamic>[],
          'chatRoomId': chatRoomId,
          'maskedPhoneAlias': maskedAlias,
          'buyerPhoneMasked': buyerPhoneMasked,
          'brokerPhoneMasked': brokerPhoneMasked,
          'contactSource': 'contact_cta',
          'callbackRequested': leadData['callbackRequested'] == true,
          'callbackStatus':
              (leadData['callbackStatus'] ?? 'not_requested').toString(),
          'unreadBuyerCount':
              (leadData['unreadBuyerCount'] as num?)?.toInt() ?? 0,
          'unreadBrokerCount':
              (leadData['unreadBrokerCount'] as num?)?.toInt() ?? 0,
          'lastMessageText': (leadData['lastMessageText'] ?? '').toString(),
          'lastMessageAt': leadData['lastMessageAt'],
          'lastMessageBy': leadData['lastMessageBy'],
          'contactClicks':
              ((leadData['contactClicks'] as num?)?.toInt() ?? 0) + 1,
          'lastIntentAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          if (!leadSnap.exists) 'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        txn.set(roomRef, {
          'leadId': leadId,
          'propertyId': safePropertyId,
          'propertyTitle':
              propertyTitle?.trim().isNotEmpty == true
                  ? propertyTitle!.trim()
                  : (roomData['propertyTitle'] ?? ''),
          'buyerId': buyerId,
          'brokerId': normalizedBrokerId,
          'participantIds': [buyerId, normalizedBrokerId],
          'buyerName': buyerName,
          'brokerName': brokerName,
          'maskedPhoneAlias': maskedAlias,
          'buyerPhoneMasked': buyerPhoneMasked,
          'brokerPhoneMasked': brokerPhoneMasked,
          'callbackRequested': roomData['callbackRequested'] == true,
          'callbackStatus':
              (roomData['callbackStatus'] ?? 'not_requested').toString(),
          'lastMessageText': (roomData['lastMessageText'] ?? '').toString(),
          'lastMessageAt': roomData['lastMessageAt'],
          'lastMessageBy': roomData['lastMessageBy'],
          'unreadBuyerCount':
              (roomData['unreadBuyerCount'] as num?)?.toInt() ?? 0,
          'unreadBrokerCount':
              (roomData['unreadBrokerCount'] as num?)?.toInt() ?? 0,
          'updatedAt': FieldValue.serverTimestamp(),
          if (!roomSnap.exists) 'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') {
        rethrow;
      }

      createdLead = true;
      final batch = _db.batch();
      batch.set(leadRef, leadCreateData);
      batch.set(roomRef, roomCreateData);
      await batch.commit();
    }

    final session = ContactSession(
      leadId: leadId,
      chatRoomId: chatRoomId,
      buyerId: buyerId,
      brokerId: normalizedBrokerId,
      propertyId: safePropertyId,
      propertyTitle: propertyTitle,
      maskedPhoneAlias: maskedAlias,
      buyerPhoneMasked: buyerPhoneMasked,
      brokerPhoneMasked: brokerPhoneMasked,
    );

    if (createdLead) {
      await _safeNotifyUser(
        userId: normalizedBrokerId,
        title: 'New contact lead',
        message: safePropertyId == null
            ? '$buyerName started a private contact thread.'
            : '$buyerName wants to discuss ${propertyTitle ?? 'a property'}.',
        type: 'lead_created',
        metadata: {
          'leadId': leadId,
          'chatRoomId': chatRoomId,
          if (safePropertyId != null) 'propertyId': safePropertyId,
        },
      );
    }

    return session;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchChatRoom(String chatRoomId) {
    return _db.collection('chat_rooms').doc(chatRoomId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(String chatRoomId) {
    return _db
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> sendTextMessage({
    required ContactSession session,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final senderId = _uid;
    final isBuyer = senderId == session.buyerId;
    final recipientId = isBuyer ? session.brokerId : session.buyerId;
    final roomRef = _db.collection('chat_rooms').doc(session.chatRoomId);
    final leadRef = _db.collection('leads').doc(session.leadId);
    final messageRef = roomRef.collection('messages').doc();

    final batch = _db.batch();
    batch.set(messageRef, {
      'chatRoomId': session.chatRoomId,
      'leadId': session.leadId,
      'senderId': senderId,
      'recipientId': recipientId,
      'senderRole': isBuyer ? 'buyer' : 'broker',
      'messageType': 'text',
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(roomRef, {
      'lastMessageText': trimmed,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageBy': senderId,
      'updatedAt': FieldValue.serverTimestamp(),
      if (isBuyer) 'unreadBrokerCount': FieldValue.increment(1),
      if (!isBuyer) 'unreadBuyerCount': FieldValue.increment(1),
    }, SetOptions(merge: true));

    batch.set(leadRef, {
      'status': isBuyer ? 'new' : 'contacted',
      if (!isBuyer) 'lastContacted': FieldValue.serverTimestamp(),
      'lastMessageText': trimmed,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageBy': senderId,
      'updatedAt': FieldValue.serverTimestamp(),
      if (isBuyer) 'unreadBrokerCount': FieldValue.increment(1),
      if (!isBuyer) 'unreadBuyerCount': FieldValue.increment(1),
    }, SetOptions(merge: true));

    await batch.commit();

    // Chat message notifications are delivered by Cloud Functions.
  }

  Future<void> markChatRead(ContactSession session) async {
    final currentUser = _uid;
    final roomRef = _db.collection('chat_rooms').doc(session.chatRoomId);
    final leadRef = _db.collection('leads').doc(session.leadId);
    final isBuyer = currentUser == session.buyerId;

    await _db.runTransaction((txn) async {
      txn.set(roomRef, {
        if (isBuyer) 'unreadBuyerCount': 0,
        if (!isBuyer) 'unreadBrokerCount': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      txn.set(leadRef, {
        if (isBuyer) 'unreadBuyerCount': 0,
        if (!isBuyer) 'unreadBrokerCount': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> requestCallback(ContactSession session, {String note = ''}) async {
    final requesterId = _uid;
    final requestedFor = requesterId == session.buyerId
        ? session.brokerId
        : session.buyerId;
    final callbackRef = _db.collection('callback_requests').doc('callback_${session.leadId}');
    final roomRef = _db.collection('chat_rooms').doc(session.chatRoomId);
    final leadRef = _db.collection('leads').doc(session.leadId);

    final batch = _db.batch();
    batch.set(callbackRef, {
      'leadId': session.leadId,
      'chatRoomId': session.chatRoomId,
      'propertyId': session.propertyId,
      'propertyTitle': session.propertyTitle ?? '',
      'brokerId': session.brokerId,
      'buyerId': session.buyerId,
      'requestedBy': requesterId,
      'requestedFor': requestedFor,
      'maskedPhoneAlias': session.maskedPhoneAlias,
      'note': note.trim(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(roomRef, {
      'callbackRequested': true,
      'callbackStatus': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(leadRef, {
      'callbackRequested': true,
      'callbackStatus': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();

    await _safeNotifyUser(
      userId: requestedFor,
      title: 'Callback requested',
      message: requesterId == session.buyerId
          ? 'A buyer requested a callback on the private line ${session.maskedPhoneAlias}.'
          : 'Broker asked you to confirm a callback on ${session.maskedPhoneAlias}.',
      type: 'callback_requested',
      metadata: {
        'leadId': session.leadId,
        'chatRoomId': session.chatRoomId,
      },
    );
  }

  Future<void> markCallbackCompleted(ContactSession session) async {
    final callbackRef = _db.collection('callback_requests').doc('callback_${session.leadId}');
    final roomRef = _db.collection('chat_rooms').doc(session.chatRoomId);
    final leadRef = _db.collection('leads').doc(session.leadId);

    final batch = _db.batch();
    batch.set(callbackRef, {
      'status': 'completed',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(roomRef, {
      'callbackRequested': false,
      'callbackStatus': 'completed',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(leadRef, {
      'callbackRequested': false,
      'callbackStatus': 'completed',
      'status': 'contacted',
      'lastContacted': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();

    final recipientId = _uid == session.buyerId ? session.brokerId : session.buyerId;
    await _safeNotifyUser(
      userId: recipientId,
      title: 'Callback completed',
      message: 'The callback request on ${session.maskedPhoneAlias} was marked complete.',
      type: 'callback_completed',
      metadata: {
        'leadId': session.leadId,
        'chatRoomId': session.chatRoomId,
      },
    );
  }

  String _displayName({
    required Map<String, dynamic> data,
    required String defaultValue,
    String? fallback,
  }) {
    final fromDoc = (data['name'] ?? '').toString().trim();
    if (fromDoc.isNotEmpty) return fromDoc;
    final fromFallback = (fallback ?? '').trim();
    if (fromFallback.isNotEmpty) return fromFallback;
    return defaultValue;
  }

  String _maskPhone(String rawPhone) {
    final digits = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 4) {
      return 'Private line';
    }
    final tail = digits.substring(digits.length - 4);
    return '••••••$tail';
  }

  String _buildMaskedAlias(String seed) {
    final compact = seed.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final suffix = compact.length <= 6
        ? compact.padLeft(6, '0')
        : compact.substring(compact.length - 6);
    return 'EST-$suffix';
  }

  Future<void> _notifyUser({
    required String userId,
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? metadata,
  }) {
    return _db.collection('notifications').add({
      'userId': userId,
      'actorId': _uid,
      'channel': 'in_app',
      'type': type,
      'title': title,
      'message': message,
      'metadata': metadata ?? <String, dynamic>{},
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  Future<void> _safeNotifyUser({
    required String userId,
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _notifyUser(
        userId: userId,
        title: title,
        message: message,
        type: type,
        metadata: metadata,
      );
    } catch (_) {
      // Contact/chat should still work even if notification rules lag behind.
    }
  }
}
