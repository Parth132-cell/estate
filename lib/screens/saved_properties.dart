import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/colors.dart';
import 'package:estatex_app/property/property_card.dart';
import 'package:estatex_app/property/property_details_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SavedPropertiesScreen extends StatelessWidget {
  const SavedPropertiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Saved Properties'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('favorites')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final favDocs = snap.data?.docs ?? [];
          if (favDocs.isEmpty) {
            return const _EmptySaved();
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: favDocs.length,
            itemBuilder: (context, index) {
              final propertyId = favDocs[index].id;
              return _SavedPropertyCard(propertyId: propertyId, uid: uid);
            },
          );
        },
      ),
    );
  }
}

class _SavedPropertyCard extends StatelessWidget {
  final String propertyId;
  final String uid;

  const _SavedPropertyCard({required this.propertyId, required this.uid});

  Future<void> _remove(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove from saved?'),
        content: const Text(
          'This property will be removed from your saved list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(propertyId)
        .delete();
  }

  String _fmt(int v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)} Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)} L';
    return '₹${NumberFormat('#,##,###').format(v)}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('properties')
          .doc(propertyId)
          .get(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return PropertyCardSkeleton(horizontal: false);
        }
        final data = snap.data?.data();
        if (data == null) return const SizedBox.shrink();

        final images = (data['images'] as List? ?? [])
            .map((e) => e.toString())
            .toList();
        final title = (data['title'] ?? '').toString();
        final city = (data['city'] ?? '').toString();
        final price = (data['price'] as num?)?.toInt() ?? 0;
        final bhk = (data['bhk'] as num?)?.toInt() ?? 0;
        final category = (data['propertyCategory'] ?? 'apartment').toString();
        final verified = data['verificationStatus'] == 'approved';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Stack(
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PropertyDetailsScreen(
                      propertyId: propertyId,
                      imageUrl: images.isNotEmpty ? images.first : '',
                      imageUrls: images,
                      price: price > 0 ? _fmt(price) : 'Price on request',
                      title: title,
                      location: city,
                      bhk: bhk > 0 ? '$bhk BHK' : '',
                      brokerId: (data['uploadedBy'] ?? '').toString(),
                      verified: verified,
                    ),
                  ),
                ),
                child: PropertyCardVertical(
                  propertyId: propertyId,
                  data: data,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PropertyDetailsScreen(
                        propertyId: propertyId,
                        imageUrl: images.isNotEmpty ? images.first : '',
                        imageUrls: images,
                        price: price > 0 ? _fmt(price) : 'Price on request',
                        title: title,
                        location: city,
                        bhk: bhk > 0 ? '$bhk BHK' : '',
                        brokerId: (data['uploadedBy'] ?? '').toString(),
                        verified: verified,
                      ),
                    ),
                  ),
                ),
              ),
              // Remove button
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => _remove(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 4),
                      ],
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptySaved extends StatelessWidget {
  const _EmptySaved();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_outline, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No saved properties',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the heart icon on any property to save it here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
