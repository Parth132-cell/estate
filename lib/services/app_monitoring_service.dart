import 'dart:ui';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppMonitoringService {
  AppMonitoringService._();

  static final AppMonitoringService instance = AppMonitoringService._();

  bool get _supportsCrashlytics {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => true,
      TargetPlatform.iOS => true,
      TargetPlatform.macOS => true,
      _ => false,
    };
  }

  Future<void> initialize() async {
    if (!_supportsCrashlytics) return;

    // Enable collection in release/profile modes, disable in debug
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      !kDebugMode,
    );
  }

  /// Handles uncaught Flutter framework errors from main.dart
  Future<void> recordFlutterError(FlutterErrorDetails details) async {
    if (!_supportsCrashlytics) return;
    // Pass fatal: true since main.dart uses this for top-level uncaught app crashes
    await FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  }

  /// Handles asynchronous and platform errors from main.dart
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = true, // Default to true for global unhandled errors
  }) async {
    if (!_supportsCrashlytics) return;
    await FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace,
      reason: reason,
      fatal: fatal,
    );
  }

  Future<void> setCurrentUser({required String userId, String? role}) async {
    if (!_supportsCrashlytics) return;

    await FirebaseCrashlytics.instance.setUserIdentifier(userId);
    if (role != null && role.trim().isNotEmpty) {
      await FirebaseCrashlytics.instance.setCustomKey(
        'role',
        role.trim().toLowerCase(),
      );
    }
  }

  Future<void> clearCurrentUser() async {
    if (!_supportsCrashlytics) return;
    await FirebaseCrashlytics.instance.setUserIdentifier('');
  }
}
