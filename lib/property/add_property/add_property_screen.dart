import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'property_editor_form.dart';
import 'property_type_selector.dart';

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  // Property category — what kind of property is being listed.
  // Default to apartment; user can change via the selector.
  String _propertyCategory = PropertyCategory.apartment.key;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to list a property')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Add Property'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(),
        builder: (context, snap) {
          // Derive listing type from role — broker = 'professional', else 'individual'
          // This replaces the confusing Owner vs Professional toggle
          // that the old PropertyTypeSelector was showing.
          final role = snap.data?.data()?['role']?.toString() ?? 'seller';
          final listingType = role == 'broker' ? 'professional' : 'individual';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Role badge — just informs, not a toggle
                _ListingTypeBadge(role: role, listingType: listingType),

                const SizedBox(height: 20),

                // ── Property category selector ──
                PropertyTypeSelector(
                  selectedCategory: _propertyCategory,
                  onCategorySelect: (cat) =>
                      setState(() => _propertyCategory = cat),
                ),

                const SizedBox(height: 24),

                // ── Editor form ──
                // Pass both listingType (owner vs broker) and propertyCategory
                // so the form can show/hide BHK appropriately.
                PropertyEditorForm(
                  listingType: listingType,
                  propertyCategory: _propertyCategory,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────
// LISTING TYPE BADGE
// Just shows the user what mode they're listing as — no toggle needed.
// ─────────────────────────────────────────

class _ListingTypeBadge extends StatelessWidget {
  final String role;
  final String listingType;

  const _ListingTypeBadge({required this.role, required this.listingType});

  @override
  Widget build(BuildContext context) {
    final isBroker = listingType == 'professional';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isBroker ? const Color(0xFFF5F0FF) : const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBroker
              ? const Color(0xFF7C3AED).withOpacity(0.3)
              : AppColors.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isBroker ? Icons.handshake_outlined : Icons.person_outline,
            size: 18,
            color: isBroker ? const Color(0xFF7C3AED) : AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isBroker
                  ? 'Listing as Broker — this will be marked as a professional listing'
                  : 'Listing as Owner — your property will show as a direct owner listing',
              style: TextStyle(
                fontSize: 13,
                color: isBroker ? const Color(0xFF5B21B6) : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
