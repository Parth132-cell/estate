import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'property_card.dart';
import 'property_details_screen.dart';

class MyPropertiesScreen extends StatelessWidget {
  const MyPropertiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view your properties')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Properties')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('properties')
            .where('uploadedBy', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Unable to load properties: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text('You have not added any properties yet'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final images = (data['images'] as List?) ?? [];

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Stack(
                  children: [
                    PropertyCard(
                      propertyId: doc.id,
                      imageUrl: images.isNotEmpty ? images[0].toString() : '',
                      price: '₹${data['price'] ?? 0}',
                      title: (data['title'] ?? '').toString(),
                      location: (data['city'] ?? '').toString(),
                      bhk: '${data['bhk'] ?? '-'} BHK',
                      verified: data['verificationStatus'] == 'approved',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PropertyDetailsScreen(
                              propertyId: doc.id,
                              imageUrl: images.isNotEmpty ? images[0].toString() : '',
                              price: '₹${data['price'] ?? 0}',
                              title: (data['title'] ?? '').toString(),
                              location: (data['city'] ?? '').toString(),
                              bhk: '${data['bhk'] ?? '-'} BHK',
                              brokerId: (data['uploadedBy'] ?? '').toString(),
                              imageUrls: images.map((e) => e.toString()).toList(),
                              verified: data['verificationStatus'] == 'approved',
                            ),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: _StatusBadge(status: (data['verificationStatus'] ?? '').toString()),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case 'approved':
        color = Colors.green;
        label = 'APPROVED';
        break;
      case 'rejected':
        color = Colors.red;
        label = 'REJECTED';
        break;
      default:
        color = Colors.orange;
        label = 'PENDING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
