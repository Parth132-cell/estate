import 'package:estatex_app/admin/admin_screen.dart';
import 'package:estatex_app/auth/phone_login_screen.dart';
import 'package:estatex_app/property/my_properties_screen.dart';
import 'package:estatex_app/profile/widgets/capability_card.dart';
import 'package:estatex_app/screens/broker_deals_screen.dart';
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
          return const Scaffold(
            body: Center(child: Text('User not logged in')),
          );
        }

        /// TEMP FLAGS (Replace with Firestore later)
        const String kycStatus = 'unverified';
        const bool canUploadProperty = true;
        const bool canHostLiveTour = false;
        const bool isProfessional = false;

        return Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              /// User Info Card
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

              const SizedBox(height: 20),

              /// Verification
              VerificationCard(
                status: kycStatus,
                onVerify: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Verification coming soon')),
                  );
                },
              ),

              const SizedBox(height: 20),

              /// Capabilities
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

              const SizedBox(height: 20),
              const Divider(),

              /// Quick Access
              const Text(
                'Quick Access',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              _navTile(
                context,
                Icons.home_work_outlined,
                'My Properties',
                const MyPropertiesScreen(),
              ),
              _navTile(
                context,
                Icons.local_offer_outlined,
                'My Offers',
                const BuyerDealsScreen(),
              ),
              _navTile(
                context,
                Icons.handshake_outlined,
                'Broker Deals',
                const BrokerDealsScreen(),
              ),
              _navTile(
                context,
                Icons.leaderboard_outlined,
                'Broker Leads',
                const BrokerLeadsScreen(),
              ),
              _navTile(
                context,
                Icons.account_balance_wallet_outlined,
                'Broker Escrow',
                const BrokerEscrowScreen(),
              ),
              _navTile(
                context,
                Icons.favorite,
                'Saved Properties',
                const SavedPropertiesScreen(),
              ),
              _navTile(
                context,
                Icons.compare,
                'Compare Properties',
                const CompareScreen(),
              ),

              const SizedBox(height: 10),
              const Divider(),

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
    Widget screen,
  ) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF5F7FF),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF1D4ED8)),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
        },
      ),
    );
  }
}
