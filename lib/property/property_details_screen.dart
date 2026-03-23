import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/property/widgets/image_carousel.dart';
import 'package:estatex_app/property/widgets/property_cta_screen.dart';
import 'package:estatex_app/screens/broker_profile_screen.dart';
import 'package:estatex_app/screens/negotiation_assistant_screen.dart';
import 'package:estatex_app/screens/visit_schedule_screen.dart';
import 'package:estatex_app/services/deal_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PropertyDetailsScreen extends StatelessWidget {
  final String propertyId;
  final String imageUrl;
  final List<String> imageUrls;
  final String price;
  final String title;
  final String location;
  final String bhk;
  final bool verified;
  final String brokerId;

  const PropertyDetailsScreen({
    super.key,
    required this.propertyId,
    required this.imageUrl,
    this.imageUrls = const [],
    required this.price,
    required this.title,
    required this.location,
    required this.bhk,
    required this.brokerId,
    this.verified = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('properties').doc(propertyId).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final liveImages = ((data['images'] as List?) ?? imageUrls)
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList();
        final safeImages = liveImages.isNotEmpty
            ? liveImages
            : (imageUrl.isNotEmpty ? [imageUrl] : <String>[]);

        final displayPrice = data['price'] != null ? '₹${data['price']}' : price;
        final displayTitle = (data['title'] ?? title).toString();
        final displayCity = (data['city'] ?? location).toString();
        final displayBhk = data['bhk'] != null ? '${data['bhk']} BHK' : bhk;
        final displayVerified = (data['verificationStatus'] ?? '') == 'approved' || verified;
        final displayBroker = (data['uploadedBy'] ?? brokerId).toString();
        final hasBroker = displayBroker.trim().isNotEmpty;

        return Scaffold(
          body: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 280,
                    pinned: true,
                    backgroundColor: Colors.white,
                    iconTheme: const IconThemeData(color: Colors.black),
                    flexibleSpace: FlexibleSpaceBar(
                      background: safeImages.isEmpty
                          ? Container(
                              color: Colors.grey.shade300,
                              child: const Icon(
                                Icons.image_not_supported,
                                size: 60,
                                color: Colors.grey,
                              ),
                            )
                          : ImageCarousel(images: safeImages),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  displayPrice,
                                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (displayVerified)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Verified',
                                    style: TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            displayTitle,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$displayBhk • $displayCity',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.person_outline),
                                label: const Text('View Broker'),
                                onPressed: hasBroker
                                    ? () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => BrokerProfileScreen(brokerId: displayBroker),
                                          ),
                                        );
                                      }
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                child: const Text('Make Offer'),
                                onPressed: () => _showOfferDialog(context, propertyId, displayBroker),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'About this property',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'A verified listing with secure escrow support, digital agreement flow, and smooth broker coordination.',
                            style: TextStyle(fontSize: 14, height: 1.6, color: Colors.grey.shade700),
                          ),
                          if (displayVerified)
  Padding(
    padding: const EdgeInsets.only(top: 24),
    child: ElevatedButton(
      onPressed: () => _featureProperty(context),
      child: const Text('Feature this property'),
    ),
  ),

const SizedBox(height: 22),

const Text(
  'About this property',
  style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  ),
),

const SizedBox(height: 10),

Text(
  'A verified listing with secure escrow support, digital agreement flow, and smooth broker coordination.',
  style: TextStyle(
    fontSize: 14,
    height: 1.6,
    color: Colors.grey.shade700,
  ),
),

const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: PropertyCtaBar(
                  onContact: () {
                    if (!hasBroker) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Broker details unavailable')),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => BrokerProfileScreen(brokerId: displayBroker)),
                    );
                  },
                  onTour: () {
                    if (!hasBroker) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Broker details unavailable')),
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VisitScheduleScreen(
                          initialPropertyId: propertyId,
                          initialBrokerId: displayBroker,
                        ),
                      ),
                    );
                  },
                  onNegotiate: () {
                    final listedPrice = data['price'] is int
                        ? data['price'] as int
                        : int.tryParse(data['price']?.toString() ?? '');

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NegotiationAssistantScreen(listedPrice: listedPrice),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _featureProperty(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to feature property')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('properties').doc(propertyId).update({
        'isFeatured': true,
        'featuredAt': FieldValue.serverTimestamp(),
        'featuredBy': uid,
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Property featured successfully')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to feature property: $e')),
      );
    }
  }

  Future<void> _showOfferDialog(
    BuildContext context,
    String propertyId,
    String brokerId,
  ) async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Offer Amount'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Enter amount'),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text('Submit'),
              onPressed: () async {
                final amount = int.tryParse(controller.text.trim());
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid offer amount')),
                  );
                  return;
                }

                await DealServices().createOffer(
                  propertyId: propertyId,
                  sellerId: brokerId,
                  amount: amount,
                );

                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Offer sent')),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
