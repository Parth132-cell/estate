import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'property_form.dart';
import 'property_type_selector.dart';
import '../../profile/widgets/verification_card.dart';

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  String listingType = 'individual'; // individual | professional

  /// TEMP user flags
  /// Later this will come from Firestore / Provider
  final bool canUploadProperty = true;
  final bool isProfessional = false;
  final String kycStatus = 'unverified'; // unverified | pending | verified

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('User not authenticated')),
      );
    }

    // 🚫 Capability gate
    if (!canUploadProperty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add Property')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: VerificationCard(
            status: kycStatus,
            onVerify: () {
              // Navigate to verification flow later
            },
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Add Property')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🧍 Owner / 🏢 Professional selector
            PropertyTypeSelector(
              selected: listingType,
              onSelect: (value) {
                if (value == 'professional' && !isProfessional) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Upgrade to Professional to list as broker',
                      ),
                    ),
                  );
                  return;
                }
                setState(() => listingType = value);
              },
            ),

            const SizedBox(height: 24),

            // 🏠 Actual property form
            PropertyForm(listingType: listingType),
          ],
        ),
      ),
    );
  }
}
