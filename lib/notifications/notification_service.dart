import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_center_screen.dart';
import 'notification_models.dart';

const AndroidNotificationChannel _estatexAlertsChannel =
    AndroidNotificationChannel(
      'estatex_alerts',
      'EstateX Alerts',
      description: 'Offer, message, and payment alerts for EstateX.',
      importance: Importance.high,
    );

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class AppNotificationService {
  factory AppNotificationService({
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) {
    if (messaging != null ||
        auth != null ||
        firestore != null ||
        localNotifications != null) {
      _instance = AppNotificationService._(
        messaging: messaging,
        auth: auth,
        firestore: firestore,
        localNotifications: localNotifications,
      );
    }
    return _instance;
  }

  AppNotificationService._({
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _db = firestore ?? FirebaseFirestore.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  static AppNotificationService _instance = AppNotificationService._();

  final FirebaseMessaging _messaging;
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FlutterLocalNotificationsPlugin _localNotifications;

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _initializeLocalNotifications();
    await _requestPermissionIfNeeded();
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await registerCurrentDeviceToken();
    await _handleInitialMessage();

    _messaging.onTokenRefresh.listen(_saveToken);
    _auth.authStateChanges().listen((user) async {
      if (user == null) {
        return;
      }
      await registerCurrentDeviceToken();
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
  }

  Future<void> _initializeLocalNotifications() async {
    if (kIsWeb) {
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        _handleLocalNotificationTap(details.payload);
      },
      onDidReceiveBackgroundNotificationResponse:
          _backgroundNotificationTapHandler,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_estatexAlertsChannel);
  }

  Future<void> _requestPermissionIfNeeded() async {
    if (kIsWeb) {
      return;
    }

    if (Platform.isIOS || Platform.isMacOS) {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      return;
    }

    await _messaging.requestPermission(alert: true, badge: true, sound: true);
  }

  Future<void> _handleInitialMessage() async {
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage == null) {
      return;
    }

    await _handleMessageTap(initialMessage);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (kIsWeb) {
      return;
    }

    if (Platform.isAndroid) {
      final remoteNotification = message.notification;
      if (remoteNotification == null) {
        return;
      }

      await _localNotifications.show(
        remoteNotification.hashCode,
        remoteNotification.title,
        remoteNotification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _estatexAlertsChannel.id,
            _estatexAlertsChannel.name,
            channelDescription: _estatexAlertsChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  Future<void> _handleMessageTap(RemoteMessage message) async {
    await _handlePayloadData(message.data);
  }

  Future<void> _handleLocalNotificationTap(String? payload) async {
    if (payload == null || payload.isEmpty) {
      _openNotificationCenter();
      return;
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        await _handlePayloadData(decoded);
        return;
      }
    } catch (_) {
      // Fall back to opening the notification center when payload parsing fails.
    }

    _openNotificationCenter();
  }

  Future<void> _handlePayloadData(Map<String, dynamic> data) async {
    final notificationId = (data['notificationId'] ?? '').toString().trim();
    if (notificationId.isNotEmpty) {
      await markRead(notificationId);
    }

    _openNotificationCenter();
  }

  void _openNotificationCenter() {
    final navigator = navigatorKey.currentState;
    final context = navigatorKey.currentContext;
    if (navigator == null || context == null) {
      return;
    }

    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const NotificationCenterScreen()),
    );
  }

  Future<void> registerCurrentDeviceToken() async {
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) {
      return;
    }
    await _saveToken(token);
  }

  Future<void> _saveToken(String token) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('fcmTokens')
          .doc(token)
          .set({
            'token': token,
            'platform': kIsWeb ? 'web' : Platform.operatingSystem,
            'enabled': true,
            'app': 'estatex',
            'updatedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      // Token save failing must never crash app startup.
      // Deploy firestore.rules with the fcmTokens subcollection rule to fix.
      debugPrint('[NotificationService] FCM token save failed: ${e.code}');
    }
  }

  Stream<List<AppNotification>> watchNotifications() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream<List<AppNotification>>.empty();
    }

    return _db
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AppNotification.fromDocument)
              .toList(growable: false),
        );
  }

  Stream<int> watchUnreadCount() {
    return watchNotifications().map(
      (items) => items.where((item) => !item.read).length,
    );
  }

  Future<void> markRead(String notificationId) async {
    if (notificationId.trim().isEmpty) {
      return;
    }

    await _db.collection('notifications').doc(notificationId).set({
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markAllRead() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    final snapshot = await _db
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .where('read', isEqualTo: false)
        .limit(50)
        .get();

    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.set(doc.reference, {
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> updatePreferences({
    required DocumentReference<Map<String, dynamic>> userRef,
    required NotificationPreferences preferences,
  }) {
    return userRef.set({
      'notificationPreferences': preferences.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

@pragma('vm:entry-point')
void _backgroundNotificationTapHandler(NotificationResponse details) {}
