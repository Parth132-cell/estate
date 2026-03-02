import 'package:estatex_app/admin/admin_screen.dart';
import 'package:estatex_app/auth/phone_login_screen.dart';
import 'package:estatex_app/property/my_properties_screen.dart';
import 'package:estatex_app/profile/widgets/capability_card.dart';
import 'package:estatex_app/screens/broker_crm_dashboard_screen.dart';
import 'package:estatex_app/screens/broker_deals_screen.dart';
import 'package:estatex_app/screens/co_broker_screen.dart';
import 'package:estatex_app/screens/broker_escrow_screen.dart';
import 'package:estatex_app/screens/broker_leads_screen.dart';
import 'package:estatex_app/screens/buyer_deals_screen.dart';
import 'package:estatex_app/screens/compare_screen.dart';
import 'package:estatex_app/screens/saved_properties.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'widgets/verification_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (user == null) {
          return const Scaffold(body: Center(child: Text('User not logged in')));
        }

        const String kycStatus = 'unverified';
        const bool canUploadProperty = true;
        const bool canHostLiveTour = false;
        const bool isProfessional = false;

        return Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                      child: Text(
                        user.phoneNumber ?? 'User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
                onUnlock: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Upgrade to Professional')),
                  );
                },
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
              _navTile(context, Icons.account_balance_wallet_outlined,
                  'Broker Escrow', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BrokerEscrowScreen()),
                );
              }),
              _navTile(context, Icons.favorite, 'Saved Properties', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SavedPropertiesScreen(),
                  ),
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
