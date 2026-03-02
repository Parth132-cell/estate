import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/comparison_service.dart';

class CompareScreen extends StatelessWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = ComparisonService();

    return Scaffold(
      appBar: AppBar(title: const Text('Compare Properties')),
      body: StreamBuilder<List<String>>(
        stream: service.comparisonIds(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final ids = snapshot.data!;

          if (ids.length < 2) {
            return const Center(
              child: Text('Select at least 2 properties to compare'),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('properties')
                .where(FieldPath.documentId, whereIn: ids.take(10).toList())
                .snapshots(),
            builder: (context, propertySnap) {
              if (!propertySnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final properties = propertySnap.data!.docs;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: properties.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    return Container(
                      width: 220,
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(blurRadius: 6, color: Colors.black12),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['title'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text('₹${data['price']}'),
                          Text('${data['bhk']} BHK'),
                          Text(data['city']),
                          const SizedBox(height: 8),
                          if (data['isFeatured'] == true)
                            const Chip(label: Text('Featured')),
                          if (data['verificationStatus'] == 'approved')
                            const Chip(label: Text('Verified')),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
