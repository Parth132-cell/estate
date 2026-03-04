import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;

        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('User not authenticated')),
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final profile = userSnapshot.data?.data() ?? <String, dynamic>{};
            final canUploadProperty = profile['canUploadProperty'] != false;
            final isProfessional =
                profile['accountType'] == 'professional' || profile['isProfessional'] == true;
            final kycStatus = (profile['kycStatus'] ?? 'unverified').toString();

            if (!canUploadProperty) {
              return Scaffold(
                appBar: AppBar(title: const Text('Add Property')),
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: VerificationCard(
                    status: kycStatus,
                    onVerify: () {},
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
                    PropertyTypeSelector(
                      selected: listingType,
                      onSelect: (value) {
                        if (value == 'professional' && !isProfessional) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Upgrade to Professional to list as broker'),
                            ),
                          );
                          return;
                        }
                        setState(() => listingType = value);
                      },
                    ),

                    const SizedBox(height: 24),

                    PropertyForm(listingType: listingType),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
