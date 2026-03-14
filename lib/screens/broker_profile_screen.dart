import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/screens/broker_deals_screen.dart';
import 'package:estatex_app/screens/broker_leads_screen.dart';
import 'package:flutter/material.dart';

class BrokerProfileScreen extends StatelessWidget {
  final String brokerId;

  const BrokerProfileScreen({super.key, required this.brokerId});

  @override
  Widget build(BuildContext context) {
    final normalizedBrokerId = brokerId.trim();
    if (normalizedBrokerId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Broker Profile')),
        body: const Center(child: Text('Broker details unavailable')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Broker Profile'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BrokerLeadsScreen()),
              );
            },
            icon: const Icon(Icons.contact_page),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BrokerDealsScreen()),
              );
            },
            icon: const Icon(Icons.details),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(normalizedBrokerId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Unable to load broker profile: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snapshot.data?.data();
          if (user == null) {
            return const Center(child: Text('Broker profile not found'));
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 45,
                  backgroundImage: user['profileImage'] != null && user['profileImage'] != ''
                      ? NetworkImage(user['profileImage'])
                      : null,
                  child: (user['profileImage'] == null || user['profileImage'] == '')
                      ? const Icon(Icons.person, size: 45)
                      : null,
                ),
                const SizedBox(height: 10),
                Text(
                  (user['name'] ?? 'Broker').toString(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                if (user['isVerifiedBroker'] == true)
                  const Chip(
                    label: Text('Verified Broker'),
                    backgroundColor: Colors.green,
                    labelStyle: TextStyle(color: Colors.white),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, color: Colors.orange),
                    Text((user['ratingAverage'] ?? 0).toString(), style: const TextStyle(fontSize: 16)),
                    Text(' (${user['totalReviews'] ?? 0})'),
                  ],
                ),
                const SizedBox(height: 12),
                if (user['phone'] != null && user['phone'] != '')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.call),
                    label: const Text('Call Broker'),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Call integration will be enabled soon')),
                      );
                    },
                  ),
                const SizedBox(height: 20),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Properties by Broker',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('properties')
                      .where('uploadedBy', isEqualTo: normalizedBrokerId)
                      .snapshots(),
                  builder: (context, propertySnap) {
                    if (propertySnap.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text('Unable to load properties: ${propertySnap.error}'),
                      );
                    }

                    if (propertySnap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      );
                    }

                    final properties = propertySnap.data?.docs ?? [];
                    if (properties.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No properties found'),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: properties.length,
                      itemBuilder: (context, index) {
                        final data = properties[index].data();
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            title: Text((data['title'] ?? '').toString()),
                            subtitle: Text('₹${data['price'] ?? 0} • ${data['city'] ?? '-'}'),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}
