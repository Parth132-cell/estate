import 'package:estatex_app/colors.dart';
import 'package:flutter/material.dart';

import '../activity/activity_screen.dart';
import '../explore/explore_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../property/add_property/add_property_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int index = 0;

  final pages = const [
    HomeScreen(),
    ExploreScreen(),
    ActivityScreen(),
    ProfileScreen(),
  ];

  void onTabChange(int i) {
    setState(() => index = i);
  }

  Future<void> openAddProperty() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddPropertyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: openAddProperty,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_home_work_outlined, color: Colors.white),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 66,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                active: index == 0,
                onTap: () => onTabChange(0),
              ),
              _NavItem(
                icon: Icons.travel_explore_rounded,
                label: 'Explore',
                active: index == 1,
                onTap: () => onTabChange(1),
              ),
              const SizedBox(width: 28),
              _NavItem(
                icon: Icons.notifications_active_outlined,
                label: 'Activity',
                active: index == 2,
                onTap: () => onTabChange(2),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                active: index == 3,
                onTap: () => onTabChange(3),
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
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : Colors.grey;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
