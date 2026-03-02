import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SavedPropertiesScreen extends StatelessWidget {
  const SavedPropertiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Properties')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('saved')
            .where('userId', isEqualTo: uid)
            .where('isFavorite', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final savedDocs = snapshot.data!.docs;

          if (savedDocs.isEmpty) {
            return const Center(child: Text('No saved properties'));
          }

          final propertyIds = savedDocs.map((e) => e['propertyId']).toList();

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('properties')
                .where(FieldPath.documentId, whereIn: propertyIds)
                .snapshots(),
            builder: (context, propertySnapshot) {
              if (!propertySnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final properties = propertySnapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: properties.length,
                itemBuilder: (context, index) {
                  final data = properties[index].data() as Map<String, dynamic>;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(data['title']),
                      subtitle: Text('${data['city']} • ₹${data['price']}'),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
