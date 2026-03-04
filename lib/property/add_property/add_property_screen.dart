import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'property_form.dart';
import 'property_type_selector.dart';

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

        return Scaffold(
          appBar: AppBar(title: const Text('Add Property')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PropertyTypeSelector(
                  selected: listingType,
                  onSelect: (value) => setState(() => listingType = value),
                ),
                const SizedBox(height: 24),
                PropertyForm(listingType: listingType),
              ],
            ),
          ),
        );
      },
    );
  }
}
