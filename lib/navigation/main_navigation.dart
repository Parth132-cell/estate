import 'dart:async';
import 'dart:async' show StreamSubscription;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/colors.dart';
import 'package:estatex_app/services/app_analytics_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../explore/explore_search_screen.dart';
import '../home/home_screen.dart';
import '../notifications/notification_center_screen.dart';
import '../notifications/notification_service.dart';
import '../profile/profile_screen.dart';
import '../property/add_property/add_property_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _index = 0;
  String _role = 'buyer'; // default until Firestore loads
  final _notificationService = AppNotificationService();
  final _analyticsService = AppAnalyticsService.instance;

  final _pages = const [
    HomeScreen(),
    ExploreSearchScreen(),
    NotificationCenterScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_analyticsService.trackScreenView('home_tab'));
    _watchRole();
  }

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roleSub;

  void _watchRole() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _roleSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) {
          final role = snap.data()?['role']?.toString() ?? 'buyer';
          if (mounted) setState(() => _role = role);
        });
  }

  @override
  void dispose() {
    _roleSub?.cancel();
    super.dispose();
  }

  void _onTabChange(int i) {
    final names = ['home_tab', 'explore_tab', 'alerts_tab', 'profile_tab'];
    unawaited(_analyticsService.trackScreenView(names[i]));
    setState(() => _index = i);
  }

  // Only sellers and brokers get the Add Property FAB
  bool get _showFab => _role == 'seller' || _role == 'broker';

  Future<void> _openAddProperty() async {
    unawaited(_analyticsService.logPropertyListingStarted());
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddPropertyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _showFab
          ? FloatingActionButton(
              onPressed: _openAddProperty,
              backgroundColor: AppColors.primary,
              tooltip: 'Add property',
              child: const Icon(
                Icons.add_home_work_outlined,
                color: Colors.white,
              ),
            )
          : null,
      bottomNavigationBar: BottomAppBar(
        shape: _showFab ? const CircularNotchedRectangle() : null,
        notchMargin: 8,
        child: SizedBox(
          height: 66,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                active: _index == 0,
                onTap: () => _onTabChange(0),
              ),
              _NavItem(
                icon: Icons.travel_explore_rounded,
                label: 'Explore',
                active: _index == 1,
                onTap: () => _onTabChange(1),
              ),
              // Space for FAB notch — only when FAB is visible
              if (_showFab) const SizedBox(width: 48),
              StreamBuilder<int>(
                stream: _notificationService.watchUnreadCount(),
                builder: (context, snapshot) {
                  return _NavItem(
                    icon: Icons.notifications_active_outlined,
                    label: 'Alerts',
                    active: _index == 2,
                    badgeCount: snapshot.data ?? 0,
                    onTap: () => _onTabChange(2),
                  );
                },
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                active: _index == 3,
                onTap: () => _onTabChange(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    this.badgeCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : Colors.grey;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color),
                if (badgeCount > 0)
                  Positioned(
                    right: -8,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
