import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/auth/phone_login_screen.dart';
import 'package:estatex_app/auth/unit_init_service.dart';

import 'package:estatex_app/navigation/main_navigation.dart';
import 'package:estatex_app/onboarding/onboarding_screen.dart';
import 'package:estatex_app/services/app_analytics_service.dart';
import 'package:estatex_app/services/app_monitoring_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.data == null) {
          unawaited(AppAnalyticsService.instance.clearCurrentUser());
          unawaited(AppMonitoringService.instance.clearCurrentUser());
          return const PhoneLoginScreen();
        }
        return _AuthenticatedGate(user: snapshot.data!);
      },
    );
  }
}

class _AuthenticatedGate extends StatefulWidget {
  final User user;
  const _AuthenticatedGate({required this.user});

  @override
  State<_AuthenticatedGate> createState() => _AuthenticatedGateState();
}

class _AuthenticatedGateState extends State<_AuthenticatedGate> {
  bool _initialising = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await UserInitService().ensureUserDocument(widget.user);
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .get();
      final data = snap.data() ?? {};
      unawaited(
        AppAnalyticsService.instance.setCurrentUser(
          userId: widget.user.uid,
          role: data['role']?.toString(),
        ),
      );
      unawaited(
        AppMonitoringService.instance.setCurrentUser(
          userId: widget.user.uid,
          role: data['role']?.toString(),
        ),
      );
      if (mounted) setState(() => _initialising = false);
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _initialising = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initialising) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 56,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Unable to connect',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Check your internet connection and try again.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {
                    _initialising = true;
                    _error = null;
                    _init();
                  }),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? {};
        final complete = data['onboardingComplete'] == true;
        final hasName = (data['name'] ?? '').toString().trim().isNotEmpty;
        if (!complete || !hasName) return const OnboardingScreen();
        return const MainNavigation();
      },
    );
  }
}
