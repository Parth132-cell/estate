import 'package:estatex_app/property/featured/featured_plan_sheet.dart';
import 'package:estatex_app/property/widgets/property_cta_screen.dart';
import 'package:estatex_app/screens/broker_profile_screen.dart';
import 'package:estatex_app/services/deal_services.dart';
import 'package:flutter/material.dart';

class PropertyDetailsScreen extends StatelessWidget {
  final String propertyId;
  final String imageUrl;
  final String price;
  final String title;
  final String location;
  final String bhk;
  final bool verified;
  // verified == approved
  final String brokerId;

  const PropertyDetailsScreen({
    super.key,
    required this.propertyId,
    required this.imageUrl,
    required this.price,
    required this.title,
    required this.location,
    required this.bhk,
    required this.brokerId,
    this.verified = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              /// 🖼 Hero Image
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: Colors.white,
                iconTheme: const IconThemeData(color: Colors.black),
                flexibleSpace: FlexibleSpaceBar(
                  background: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return Container(
                        color: Colors.grey.shade300,
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 60,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
              ),

              /// 📄 Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// 💰 Price + Verified
                      Row(
                        children: [
                          Text(
                            price,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (verified)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Verified',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      /// 🏠 Title
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 6),

                      /// 📍 Location
                      Text(
                        '$bhk • $location',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),

                      const SizedBox(height: 24),

                      TextButton(
                        child: const Text("View Broker"),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  BrokerProfileScreen(brokerId: brokerId),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      ElevatedButton(
                        child: const Text("Make Offer"),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              final controller = TextEditingController();

                              return AlertDialog(
                                title: const Text("Enter Offer Amount"),
                                content: TextField(
                                  controller: controller,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    hintText: "Enter amount",
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    child: const Text("Cancel"),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  ElevatedButton(
                                    child: const Text("Submit"),
                                    onPressed: () async {
                                      final amount = int.parse(controller.text);

                                      await DealServices().createOffer(
                                        propertyId: propertyId,
                                        brokerId: brokerId,
                                        amount: amount,
                                      );

                                      Navigator.pop(context);

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text("Offer sent"),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),

                      /// 🔑 Highlights
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          _Highlight(icon: Icons.king_bed, label: 'Bedrooms'),
                          _Highlight(icon: Icons.bathtub, label: 'Bathrooms'),
                          _Highlight(icon: Icons.square_foot, label: 'Area'),
                        ],
                      ),

                      const SizedBox(height: 32),

                      /// 📝 Description
                      const Text(
                        'About this property',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'This is a well-maintained property located in a prime area with excellent connectivity, good ventilation, and nearby essential amenities.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: Colors.grey.shade700,
                        ),
                      ),

                      /// ⭐ FEATURE PROPERTY BUTTON (ONLY IF VERIFIED)
                      if (verified) ...[
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                              ),
                              builder: (_) => const FeaturePlansSheet(),
                            );
                          },
                          child: const Text('Feature this property'),
                        ),
                      ],

                      /// Space for CTA bar
                      const SizedBox(height: 140),
                    ],
                  ),
                ),
              ),
            ],
          ),

          /// 📌 Sticky CTA
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: PropertyCtaBar(
              onContact: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contact action coming soon')),
                );
              },
              onTour: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Live tour coming soon')),
                );
              },
              onNegotiate: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Negotiation coming soon')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 🔹 Small reusable highlight widget
class _Highlight extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Highlight({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 28),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
