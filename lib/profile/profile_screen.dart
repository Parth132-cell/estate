import 'package:estatex_app/admin/admin_screen.dart';
import 'package:estatex_app/auth/phone_login_screen.dart';
import 'package:estatex_app/profile/widgets/capability_card.dart';
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

        /// 🔧 TEMP USER FLAGS
    /// Replace with Firestore later
    const String kycStatus = 'unverified';
    const bool canUploadProperty = true;
    const bool canHostLiveTour = false;
    const bool isProfessional = false;

        return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          /// 👤 User Info
          Text(
            user.phoneNumber ?? 'User',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 24),

          /// 🔐 Verification
          VerificationCard(
            status: kycStatus,
            onVerify: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Verification flow coming soon')),
              );
            },
          ),

          const SizedBox(height: 32),

          /// ⚙️ Capabilities
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

          const Divider(height: 40),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminScreen()),
              );
            },
            child: const Text('Open Admin Panel'),
          ),

          /// ❤️ Saved properties
          ListTile(
            leading: const Icon(Icons.favorite),
            title: const Text('Saved Properties'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SavedPropertiesScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.compare),
            title: const Text('Compare Properties'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CompareScreen()),
              );
            },
          ),

          /// 🚪 Logout
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              final confirm = await showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await FirebaseAuth.instance.signOut();

                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
        );
      },
    );
  }
}
