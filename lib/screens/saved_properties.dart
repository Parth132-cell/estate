import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SavedPropertiesScreen extends StatelessWidget {
  const SavedPropertiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view saved properties')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Properties')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('saved')
            .where('userId', isEqualTo: user.uid)
            .where('isFavorite', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Unable to load saved list: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final savedDocs = snapshot.data?.docs ?? [];
          if (savedDocs.isEmpty) {
            return const Center(child: Text('No saved properties'));
          }

          final propertyIds = savedDocs
              .map((e) => (e.data()['propertyId'] ?? '').toString())
              .where((e) => e.isNotEmpty)
              .toList();

          if (propertyIds.isEmpty) {
            return const Center(child: Text('No saved properties'));
          }

          return FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            future: _loadProperties(propertyIds),
            builder: (context, propertySnapshot) {
              if (propertySnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (propertySnapshot.hasError) {
                return Center(child: Text('Unable to load properties: ${propertySnapshot.error}'));
              }

              final properties = propertySnapshot.data ?? [];
              if (properties.isEmpty) {
                return const Center(child: Text('No saved properties available'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: properties.length,
                itemBuilder: (context, index) {
                  final data = properties[index].data();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text((data['title'] ?? '').toString()),
                      subtitle: Text('${data['city'] ?? '-'} • ₹${data['price'] ?? 0}'),
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

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _loadProperties(
    List<String> propertyIds,
  ) async {
    final chunks = <List<String>>[];
    for (int i = 0; i < propertyIds.length; i += 10) {
      final end = (i + 10 < propertyIds.length) ? i + 10 : propertyIds.length;
      chunks.add(propertyIds.sublist(i, end));
    }

    final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final chunk in chunks) {
      final snap = await FirebaseFirestore.instance
          .collection('properties')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      docs.addAll(snap.docs);
    }

    return docs;
  }
}
