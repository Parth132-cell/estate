import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppAnalyticsService {
  AppAnalyticsService._();

  static final AppAnalyticsService instance = AppAnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Cached per-session — avoids repeatedly attempting a write that will
  // always be denied for non-admin users. Reset on setCurrentUser/clearCurrentUser.
  bool? _isAdminCache;
  String? _cachedUid;

  bool get _supportsAnalytics {
    if (kIsWeb) return true;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => true,
      TargetPlatform.iOS => true,
      TargetPlatform.macOS => true,
      _ => false,
    };
  }

  NavigatorObserver? get navigatorObserver {
    if (!_supportsAnalytics) return null;
    return FirebaseAnalyticsObserver(analytics: _analytics);
  }

  Future<void> setCurrentUser({required String userId, String? role}) async {
    if (_supportsAnalytics) {
      await _analytics.setUserId(id: userId);
      if (role != null && role.trim().isNotEmpty) {
        await _analytics.setUserProperty(
          name: 'role',
          value: role.trim().toLowerCase(),
        );
      }
    }

    // Reset admin cache whenever the user changes
    _cachedUid = userId;
    _isAdminCache = role?.trim().toLowerCase() == 'admin';
  }

  Future<void> clearCurrentUser() async {
    if (_supportsAnalytics) {
      await _analytics.setUserId(id: '');
    }
    _cachedUid = null;
    _isAdminCache = null;
  }

  Future<void> trackScreenView(String screenName) async {
    if (_supportsAnalytics) {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenName,
      );
    }
    await _incrementMetric('screen_views');
  }

  Future<void> logOtpRequested({required String countryCode}) {
    return _logEvent(
      name: 'otp_requested',
      metricKey: 'otp_requests',
      parameters: {'country_code': countryCode},
    );
  }

  Future<void> logOtpVerified() {
    return _logEvent(name: 'otp_verified', metricKey: 'otp_verified');
  }

  Future<void> logPropertyViewed({required String propertyId, String? source}) {
    return _logEvent(
      name: 'property_viewed',
      metricKey: 'property_views',
      parameters: {
        'property_id': propertyId,
        if (source != null) 'source': source,
      },
    );
  }

  Future<void> logPropertyListingStarted() {
    return _logEvent(
      name: 'property_listing_started',
      metricKey: 'listing_starts',
    );
  }

  Future<void> logOfferMade({required String propertyId}) {
    return _logEvent(
      name: 'offer_made',
      metricKey: 'offers_made',
      parameters: {'property_id': propertyId},
    );
  }

  Future<void> logDealClosed({required String dealId}) {
    return _logEvent(
      name: 'deal_closed',
      metricKey: 'deals_closed',
      parameters: {'deal_id': dealId},
    );
  }

  Future<void> logAdminPropertyModerated({
    required String status,
    required String propertyId,
  }) {
    return _logEvent(
      name: 'admin_property_moderated',
      metricKey: 'properties_moderated',
      parameters: {'status': status, 'property_id': propertyId},
    );
  }

  Future<void> logOfferSubmitted({
    required String propertyId,
    required int amount,
  }) {
    return _logEvent(
      name: 'offer_submitted',
      metricKey: 'offers_submitted',
      parameters: {'property_id': propertyId, 'amount': amount},
    );
  }

  Future<void> logLeadCreated({required String priority}) {
    return _logEvent(
      name: 'lead_created',
      metricKey: 'leads_created',
      parameters: {'priority': priority},
    );
  }

  // ─────────────────────────────────────────
  // PRIVATE HELPERS
  // ─────────────────────────────────────────

  Future<void> _logEvent({
    required String name,
    required String metricKey,
    Map<String, Object>? parameters,
  }) async {
    if (_supportsAnalytics) {
      await _analytics.logEvent(name: name, parameters: parameters);
    }
    await _incrementMetric(metricKey);
  }

  /// Returns true only if we have a cached confirmation that the current
  /// user is an admin. Defaults to false (skip the write) for everyone
  /// else, including before the cache is populated — this avoids ever
  /// attempting the admin_metrics_daily write for non-admin users, which
  /// eliminates the PERMISSION_DENIED logcat/Crashlytics noise at the
  /// source rather than just catching it after the fact.
  bool get _isLikelyAdmin {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    if (_cachedUid != uid) return false; // cache stale or not yet set
    return _isAdminCache == true;
  }

  Future<void> _incrementMetric(String key) async {
    if (!_isLikelyAdmin) {
      // Skip entirely — Firestore rules would deny this write anyway for
      // non-admin users. Firebase Analytics (logged above) already
      // captured the event, so no data is lost.
      return;
    }

    try {
      final today = _todayKey();
      await _db.collection('admin_metrics_daily').doc(today).set({
        'eventCounters': {key: FieldValue.increment(1)},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      debugPrint('[AppAnalyticsService] metric write failed: ${e.code}');
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
