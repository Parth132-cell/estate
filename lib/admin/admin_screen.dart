import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/admin_services.dart';
import 'admin_disputes_screen.dart';
import 'admin_fraud_screen.dart';
import 'admin_property_tile.dart';
import 'admin_visits_screen.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('User not logged in')));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final role = (userSnapshot.data?.data()?['role'] ?? '').toString().toLowerCase();
        if (role != 'admin') {
          return const Scaffold(
            body: Center(child: Text('Access denied. Admin role required.')),
          );
        }

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Admin Moderation Panel'),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Pending'),
                  Tab(text: 'Approved'),
                  Tab(text: 'Rejected'),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.report_problem_outlined),
                  tooltip: 'Disputes',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminDisputesScreen()),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.shield_outlined),
                  tooltip: 'Fraud Alerts',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminFraudScreen()),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.event_note_outlined),
                  tooltip: 'Visit Monitoring',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminVisitsScreen()),
                    );
                  },
                ),
              ],
            ),
            body: const TabBarView(
              children: [
                _PropertyModerationList(status: 'pending'),
                _PropertyModerationList(status: 'approved'),
                _PropertyModerationList(status: 'rejected'),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PropertyModerationList extends StatelessWidget {
  final String status;

  const _PropertyModerationList({required this.status});

  @override
  Widget build(BuildContext context) {
    final service = AdminService();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.propertiesByStatus(status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No $status properties'));
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();

            return AdminPropertyTile(
              propertyId: doc.id,
              title: (data['title'] ?? 'Untitled').toString(),
              city: (data['city'] ?? 'Unknown').toString(),
              price: (data['price'] as num?)?.toInt() ?? 0,
              status: (data['verificationStatus'] ?? 'pending').toString(),
              rejectionReason: data['rejectionReason']?.toString(),
            );
          },
        );
      },
    );
  }
}
