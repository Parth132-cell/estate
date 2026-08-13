import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/admin/admin_screen.dart';
import 'package:estatex_app/auth/phone_login_screen.dart';
import 'package:estatex_app/notifications/notification_models.dart';
import 'package:estatex_app/notifications/notification_preferences_card.dart';
import 'package:estatex_app/property/my_properties_screen.dart';
import 'package:estatex_app/profile/widgets/capability_card.dart';
import 'package:estatex_app/profile/role_switch/role_switch_screen.dart';
import 'package:estatex_app/screens/ai_recommendations_screen.dart';
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

    final profileRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: profileRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final name = (data['name'] ?? '').toString();
        final phone = (data['phone'] ?? user.phoneNumber ?? '').toString();
        final role = (data['role'] ?? 'buyer').toString();
        final kycStatus = (data['kycStatus'] ?? 'unverified').toString();
        final canUploadProperty = data['canUploadProperty'] != false;
        final canHostLiveTour = data['canHostLiveTour'] == true;
        final isProfessional = role == 'broker' || role == 'admin';
        final isIncomplete = name.trim().isEmpty;
        final notificationPreferences = NotificationPreferences.fromUserData(
          data,
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            backgroundColor: Colors.white,
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Incomplete profile banner ──
              if (isIncomplete)
                Card(
                  color: Colors.amber.shade50,
                  child: ListTile(
                    leading: const Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                    ),
                    title: const Text('Complete your profile'),
                    subtitle: const Text(
                      'Add your name to complete profile setup.',
                    ),
                    trailing: TextButton(
                      onPressed: () => _showEditProfileDialog(
                        context: context,
                        userRef: profileRef,
                        currentName: name,
                      ),
                      child: const Text('Complete'),
                    ),
                  ),
                ),

              // ── Profile header card ──
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
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _roleLabel(role),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _showEditProfileDialog(
                        context: context,
                        userRef: profileRef,
                        currentName: name,
                      ),
                      icon: const Icon(Icons.edit, color: Colors.white),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── KYC / verification ──
              VerificationCard(
                status: kycStatus,
                onVerify: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Verification flow coming soon'),
                    ),
                  );
                },
              ),

              const SizedBox(height: 18),

              // ── Capabilities ──
              const Text(
                'Capabilities',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
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

              const SizedBox(height: 16),

              // ── Notification prefs ──
              NotificationPreferencesCard(
                userRef: profileRef,
                preferences: notificationPreferences,
              ),

              const SizedBox(height: 16),

              // ══ ROLE-GATED MENU ══════════════════════
              // BUYER section — visible to buyer + admin
              if (role == 'buyer' || role == 'admin') ...[
                _sectionHeader('🧑 Buyer'),
                _navTile(
                  context,
                  Icons.local_offer_outlined,
                  'My Offers',
                  () => _push(context, const BuyerDealsScreen()),
                ),
                _navTile(
                  context,
                  Icons.favorite_outline,
                  'Saved Properties',
                  () => _push(context, const SavedPropertiesScreen()),
                ),
                _navTile(
                  context,
                  Icons.compare_outlined,
                  'Compare Properties',
                  () => _push(context, const CompareScreen()),
                ),
                _navTile(
                  context,
                  Icons.auto_awesome_outlined,
                  'AI Recommendations',
                  () => _push(context, const AiRecommendationsScreen()),
                ),
                _navTile(
                  context,
                  Icons.support_agent_outlined,
                  'Negotiation Assistant',
                  () => _push(context, const NegotiationAssistantScreen()),
                ),
                _navTile(
                  context,
                  Icons.event_available_outlined,
                  'My Site Visits',
                  () => _push(context, const VisitScheduleScreen()),
                ),
                const SizedBox(height: 12),
              ],

              // SELLER section — visible to seller + admin
              if (role == 'seller' || role == 'admin') ...[
                _sectionHeader('🏠 Seller'),
                _navTile(
                  context,
                  Icons.home_work_outlined,
                  'My Properties',
                  () => _push(context, const MyPropertiesScreen()),
                ),
                _navTile(
                  context,
                  Icons.receipt_long_outlined,
                  'Incoming Offers',
                  () => _push(context, const BrokerDealsScreen()),
                ),
                _navTile(
                  context,
                  Icons.event_available_outlined,
                  'Visit Requests',
                  () => _push(context, const VisitScheduleScreen()),
                ),
                _navTile(
                  context,
                  Icons.video_camera_front_outlined,
                  'Live Tours',
                  () => _push(context, const LiveTourScreen()),
                ),
                const SizedBox(height: 12),
              ],

              // BROKER section — visible to broker + admin
              if (role == 'broker' || role == 'admin') ...[
                _sectionHeader('🤝 Broker'),
                _navTile(
                  context,
                  Icons.analytics_outlined,
                  'CRM Dashboard',
                  () => _push(context, const BrokerCrmDashboardScreen()),
                ),
                _navTile(
                  context,
                  Icons.leaderboard_outlined,
                  'My Leads',
                  () => _push(context, const BrokerLeadsScreen()),
                ),
                _navTile(
                  context,
                  Icons.handshake_outlined,
                  'My Deals',
                  () => _push(context, const BrokerDealsScreen()),
                ),
                _navTile(
                  context,
                  Icons.groups_2_outlined,
                  'Co-broker Collaboration',
                  () => _push(context, const CoBrokerScreen()),
                ),
                _navTile(
                  context,
                  Icons.account_balance_wallet_outlined,
                  'Escrow Management',
                  () => _push(context, const BrokerEscrowScreen()),
                ),
                _navTile(
                  context,
                  Icons.home_work_outlined,
                  'My Listings',
                  () => _push(context, const MyPropertiesScreen()),
                ),
                _navTile(
                  context,
                  Icons.event_available_outlined,
                  'Visit Scheduler',
                  () => _push(context, const VisitScheduleScreen()),
                ),
                _navTile(
                  context,
                  Icons.video_camera_front_outlined,
                  'Live Tours',
                  () => _push(context, const LiveTourScreen()),
                ),
                _navTile(
                  context,
                  Icons.support_agent_outlined,
                  'Negotiation Assistant',
                  () => _push(context, const NegotiationAssistantScreen()),
                ),
                const SizedBox(height: 12),
              ],

              // ── Admin panel ──
              if (role == 'admin') ...[
                _sectionHeader('🛡 Admin'),
                _navTile(
                  context,
                  Icons.admin_panel_settings_outlined,
                  'Admin Panel',
                  () => _push(context, const AdminScreen()),
                ),
                const SizedBox(height: 12),
              ],

              const Divider(height: 32),

              // ── Manage Roles ──
              Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                color: const Color(0xFFF5F7FF),
                child: ListTile(
                  leading: const Icon(
                    Icons.manage_accounts_outlined,
                    color: Color(0xFF1D4ED8),
                  ),
                  title: const Text('Manage Roles'),
                  subtitle: const Text(
                    'Add seller or broker role, switch active view',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _push(context, const RoleSwitchScreen()),
                ),
              ),

              const Divider(height: 32),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
                    (route) => false,
                  );
                },
              ),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────

  String _roleLabel(String role) {
    switch (role) {
      case 'broker':
        return '🤝 Broker';
      case 'seller':
        return '🏠 Seller';
      case 'admin':
        return '🛡 Admin';
      default:
        return '🧑 Buyer';
    }
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF374151),
        ),
      ),
    );
  }

  Widget _navTile(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      color: const Color(0xFFF5F7FF),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF1D4ED8)),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Future<void> _showEditProfileDialog({
    required BuildContext context,
    required DocumentReference<Map<String, dynamic>> userRef,
    required String currentName,
  }) async {
    final nameCtrl = TextEditingController(text: currentName);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Role changes are handled by admin review.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await userRef.set({
                'name': nameCtrl.text.trim(),
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
  }
}
