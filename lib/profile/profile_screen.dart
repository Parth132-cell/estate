import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/admin/admin_screen.dart';
import 'package:estatex_app/auth/phone_login_screen.dart';
import 'package:estatex_app/property/my_properties_screen.dart';
import 'package:estatex_app/profile/widgets/capability_card.dart';
import 'package:estatex_app/screens/ai_recommendations_screen.dart';
import 'package:estatex_app/screens/ar_preview_screen.dart';
import 'package:estatex_app/screens/broker_crm_dashboard_screen.dart';
import 'package:estatex_app/screens/broker_deals_screen.dart';
import 'package:estatex_app/screens/broker_escrow_screen.dart';
import 'package:estatex_app/screens/broker_leads_screen.dart';
import 'package:estatex_app/screens/buyer_deals_screen.dart';
import 'package:estatex_app/screens/co_broker_screen.dart';
import 'package:estatex_app/screens/compare_screen.dart';
import 'package:estatex_app/screens/live_tour_screen.dart';
import 'package:estatex_app/screens/negotiation_assistant_screen.dart';
import 'package:estatex_app/screens/saved_properties.dart';
import 'package:estatex_app/screens/visit_schedule_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'widgets/verification_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('User not logged in')));
    }

    final profileRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: profileRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final name = (data['name'] ?? '').toString();
        final phone = (data['phone'] ?? user.phoneNumber ?? '').toString();
        final role = (data['role'] ?? 'user').toString();
        final kycStatus = (data['kycStatus'] ?? 'unverified').toString();
        final canUploadProperty = data['canUploadProperty'] != false;
        final canHostLiveTour = data['canHostLiveTour'] == true;
        final isProfessional = role == 'broker' || role == 'admin';
        final isIncomplete = name.trim().isEmpty;

        return Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (isIncomplete)
                Card(
                  color: Colors.amber.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.info_outline, color: Colors.orange),
                    title: const Text('Complete your profile'),
                    subtitle: const Text('Add your name to complete profile setup.'),
                    trailing: TextButton(
                      onPressed: () => _showEditProfileDialog(
                        context: context,
                        userRef: profileRef,
                        currentName: name,
                        currentRole: role,
                      ),
                      child: const Text('Complete'),
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                  ),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, color: Color(0xFF1D4ED8)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.trim().isEmpty ? 'Unnamed user' : name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            phone,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Text(
                            role.toUpperCase(),
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _showEditProfileDialog(
                        context: context,
                        userRef: profileRef,
                        currentName: name,
                        currentRole: role,
                      ),
                      icon: const Icon(Icons.edit, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              VerificationCard(
                status: kycStatus,
                onVerify: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Verification flow coming soon')),
                  );
                },
              ),
              const SizedBox(height: 18),
              const Text(
                'Capabilities',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              CapabilityTile(
                title: 'Upload Property',
                enabled: canUploadProperty,
                onUnlock: () {},
              ),
              CapabilityTile(
                title: 'Host Live Tour',
                enabled: canHostLiveTour,
                onUnlock: () {},
              ),
              CapabilityTile(
                title: 'Professional Listing',
                enabled: isProfessional,
                onUnlock: () {},
              ),
              const SizedBox(height: 12),
              const Text(
                'Quick Access',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              _navTile(context, Icons.home_work_outlined, 'My Properties', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyPropertiesScreen()),
                );
              }),
              _navTile(context, Icons.local_offer_outlined, 'My Offers', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BuyerDealsScreen()),
                );
              }),
              _navTile(context, Icons.handshake_outlined, 'Broker Deals', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BrokerDealsScreen()),
                );
              }),
              _navTile(context, Icons.leaderboard_outlined, 'Broker Leads', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BrokerLeadsScreen()),
                );
              }),
              _navTile(context, Icons.analytics_outlined, 'CRM Dashboard', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BrokerCrmDashboardScreen()),
                );
              }),
              _navTile(context, Icons.groups_2_outlined, 'Co-broker Collaboration', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CoBrokerScreen()),
                );
              }),
              _navTile(context, Icons.video_camera_front_outlined, 'Live Tours', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LiveTourScreen()),
                );
              }),
              _navTile(context, Icons.event_available_outlined, 'Visit Scheduler', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VisitScheduleScreen()),
                );
              }),
              _navTile(context, Icons.auto_awesome_outlined, 'AI Recommendations', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiRecommendationsScreen()),
                );
              }),
              _navTile(context, Icons.support_agent_outlined, 'Negotiation Assistant', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NegotiationAssistantScreen()),
                );
              }),
              _navTile(context, Icons.view_in_ar_outlined, 'AR Preview', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ArPreviewScreen()),
                );
              }),
              _navTile(context, Icons.account_balance_wallet_outlined, 'Broker Escrow', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BrokerEscrowScreen()),
                );
              }),
              _navTile(context, Icons.favorite, 'Saved Properties', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SavedPropertiesScreen()),
                );
              }),
              _navTile(context, Icons.compare, 'Compare Properties', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CompareScreen()),
                );
              }),
              const Divider(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminScreen()),
                  );
                },
                child: const Text('Open Admin Panel'),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditProfileDialog({
    required BuildContext context,
    required DocumentReference<Map<String, dynamic>> userRef,
    required String currentName,
    required String currentRole,
  }) async {
    final nameCtrl = TextEditingController(text: currentName);
    String selectedRole = ['user', 'broker', 'admin'].contains(currentRole)
        ? currentRole
        : 'user';

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit profile'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name (optional)'),
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Role: ${selectedRole.toUpperCase()}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await userRef.set({
                  'name': nameCtrl.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    nameCtrl.dispose();
  }

  Widget _navTile(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF5F7FF),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF1D4ED8)),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
