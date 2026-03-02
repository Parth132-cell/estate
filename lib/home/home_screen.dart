import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../property/property_card.dart';
import '../property/property_card_skeleton.dart';
import '../property/property_details_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EstateX')),
      body: ListView(
        padding: const EdgeInsets.only(top: 16),
        children: const [
          _FeaturedSection(),
          SizedBox(height: 32),
          _RecentSection(),
          SizedBox(height: 32),
        ],
      ),
    );
  }
}

/* ---------------- FEATURED SECTION ---------------- */

class _FeaturedSection extends StatelessWidget {
  const _FeaturedSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Featured Properties',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),

        SizedBox(
          height: 250,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('properties')
                .where('verificationStatus', isEqualTo: 'approved')
                .where('isFeatured', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 16),
                  itemCount: 3,
                  itemBuilder: (_, __) => const PropertyCardSkeleton(),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'No featured properties yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              final docs = snapshot.data!.docs;

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;

                  return _PropertyItem(data: data, propertyId: docs[index].id);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/* ---------------- RECENT SECTION ---------------- */

class _RecentSection extends StatelessWidget {
  const _RecentSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Recently Added',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),

        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('properties')
              .where('verificationStatus', isEqualTo: 'approved')
              .orderBy('createdAt', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: PropertyCardSkeleton(),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'No properties yet',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }

            final docs = snapshot.data!.docs;

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: _PropertyItem(data: data, propertyId: docs[index].id),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

/* ---------------- COMMON PROPERTY ITEM ---------------- */

class _PropertyItem extends StatelessWidget {
  final Map<String, dynamic> data;
  final String propertyId;

  const _PropertyItem({required this.data, required this.propertyId});

  @override
  Widget build(BuildContext context) {
    final images = data['images'] as List? ?? [];

    return PropertyCard(
      propertyId: propertyId,
      imageUrl: images.isNotEmpty ? images[0] : '',
      price: '₹${data['price']}',
      title: data['title'],
      location: data['city'],
      bhk: '${data['bhk']} BHK',
      verified: true,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PropertyDetailsScreen(
              propertyId: propertyId,
              imageUrl: images.isNotEmpty ? images[0] : '',
              price: '₹${data['price']}',
              title: data['title'],
              location: data['city'],
              bhk: '${data['bhk']} BHK',
              brokerId: data['uploadedBy'],
              verified: true,
            ),
          ),
        );
      },
    );
  }
}
