import 'dart:async';

import 'package:estatex_app/app_theme.dart';

import 'package:estatex_app/auth/auth_gate_update.dart';
import 'package:estatex_app/notifications/notification_service.dart';
import 'package:estatex_app/services/app_analytics_service.dart';
import 'package:estatex_app/services/app_monitoring_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';

Future<void> main() async {
  // ── Ensure Flutter binding before anything async ──
  WidgetsFlutterBinding.ensureInitialized();

  // ── Lock to portrait ──
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── Transparent status bar ──
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // ── Firebase init — run in background, don't block first frame ──
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ── Register error handlers before any UI ──
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(AppMonitoringService.instance.recordFlutterError(details));
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(AppMonitoringService.instance.recordError(error, stack));
    return true;
  };

  // ── Init notification service after Firebase ──
  // Use unawaited so it doesn't block first paint
  unawaited(_initServicesInBackground());

  runApp(const ProviderScope(child: EstateXApp()));
}

/// Initialise notification + analytics service off the main thread start.
/// This is what was causing the 95-frame skip — all these awaits were
/// blocking the first render in the old main().
Future<void> _initServicesInBackground() async {
  try {
    await AppNotificationService().initialize();
  } catch (e) {
    debugPrint('[EstateX] Notification init failed: $e');
  }
}

class EstateXApp extends StatelessWidget {
  const EstateXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EstateX',
      debugShowCheckedModeBanner: false,

      // ── Apply the design system ──
      theme: AppTheme.light,

      // ── Analytics navigator observer ──
      navigatorObservers: [
        if (AppAnalyticsService.instance.navigatorObserver != null)
          AppAnalyticsService.instance.navigatorObserver!,
      ],

      // ── Error widget — shown when a widget crashes ──
      builder: (context, child) {
        // Override error widget in release mode
        ErrorWidget.builder = (details) => _AppErrorWidget(
          message: kDebugMode ? details.exceptionAsString() : null,
        );
        return child ?? const SizedBox.shrink();
      },

      home: const AuthGate(),
    );
  }
}

class _AppErrorWidget extends StatelessWidget {
  final String? message;
  const _AppErrorWidget({this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 56, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please restart the app. If the problem continues, contact support.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              if (message != null && kDebugMode) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    message!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
