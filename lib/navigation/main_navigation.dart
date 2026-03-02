import 'package:estatex_app/colors.dart';
import 'package:flutter/material.dart';

import '../home/home_screen.dart';
import '../explore/explore_screen.dart';
import '../activity/activity_screen.dart';
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
    SizedBox(), // placeholder for +
    ActivityScreen(),
    ProfileScreen(),
  ];

  void onTap(int i) {
    if (i == 2) {
      // ➕ Add Property
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddPropertyScreen()),
      );
      return;
    }
    setState(() => index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Explore'),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle, size: 36),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Activity',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
