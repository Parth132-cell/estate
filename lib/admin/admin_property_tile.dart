import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminPropertyTile extends StatelessWidget {
  final String propertyId;
  final String title;
  final String city;
  final int price;

  const AdminPropertyTile({
    super.key,
    required this.propertyId,
    required this.title,
    required this.city,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('properties')
        .doc(propertyId);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('₹$price • $city'),

            const SizedBox(height: 12),

            Row(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await ref.update({'verificationStatus': 'approved'});

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Property approved')),
                    );
                  },
                  child: const Text('Approve'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () async {
                    await ref.update({'verificationStatus': 'rejected'});

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Property rejected')),
                    );
                  },
                  child: const Text('Reject'),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.star_border),
                  tooltip: 'Feature property',
                  onPressed: () async {
                    await ref.update({'isFeatured': true});

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Marked as featured')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
