import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/property/property_details_screen.dart';
import 'package:estatex_app/services/ai_recommendation_service.dart';
import 'package:flutter/material.dart';

class AiRecommendationsScreen extends StatelessWidget {
  const AiRecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Recommendations')),
      body: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        stream: AiRecommendationService().recommendations(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!;
          if (docs.isEmpty) {
            return const Center(child: Text('No recommendations available yet'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final images = ((data['images'] as List?) ?? [])
                  .map((e) => e.toString())
                  .toList();

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFEFF4FF),
                    child: Text('#${index + 1}'),
                  ),
                  title: Text((data['title'] ?? 'Property').toString()),
                  subtitle: Text(
                    '₹${data['price'] ?? '-'} • ${data['city'] ?? '-'} • ${data['bhk'] ?? '-'} BHK',
                  ),
                  trailing: data['isFeatured'] == true
                      ? const Chip(label: Text('AI Pick'))
                      : null,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PropertyDetailsScreen(
                          propertyId: doc.id,
                          imageUrl: images.isNotEmpty ? images.first : '',
                          imageUrls: images,
                          price: '₹${data['price'] ?? '-'}',
                          title: (data['title'] ?? 'Property').toString(),
                          location: (data['city'] ?? '-').toString(),
                          bhk: '${data['bhk'] ?? '-'} BHK',
                          brokerId: (data['uploadedBy'] ?? '').toString(),
                          verified: (data['verificationStatus'] ?? '') == 'approved',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
