import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/screens/broker_deals_screen.dart';
import 'package:estatex_app/screens/broker_leads_screen.dart';
import 'package:flutter/material.dart';

class BrokerProfileScreen extends StatelessWidget {
  final String brokerId;

  const BrokerProfileScreen({super.key, required this.brokerId});

  @override
  Widget build(BuildContext context) {
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
            icon: Icon(Icons.contact_page),
          ),

          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BrokerDealsScreen()),
              );
            },
            icon: Icon(Icons.details),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(brokerId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),

                /// Profile Image
                CircleAvatar(
                  radius: 45,
                  backgroundImage:
                      user['profileImage'] != null && user['profileImage'] != ''
                      ? NetworkImage(user['profileImage'])
                      : null,
                  child:
                      (user['profileImage'] == null ||
                          user['profileImage'] == '')
                      ? const Icon(Icons.person, size: 45)
                      : null,
                ),

                const SizedBox(height: 10),

                /// Name
                Text(
                  user['name'] ?? 'Broker',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                /// Verified Badge
                if (user['isVerifiedBroker'] == true)
                  const Chip(
                    label: Text('Verified Broker'),
                    backgroundColor: Colors.green,
                    labelStyle: TextStyle(color: Colors.white),
                  ),

                const SizedBox(height: 8),

                /// Rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, color: Colors.orange),
                    Text(
                      (user['ratingAverage'] ?? 0).toString(),
                      style: const TextStyle(fontSize: 16),
                    ),
                    Text(' (${user['totalReviews'] ?? 0})'),
                  ],
                ),

                const SizedBox(height: 12),

                /// Call Button
                if (user['phone'] != null && user['phone'] != '')
                  ElevatedButton.icon(
                    icon: const Icon(Icons.call),
                    label: const Text('Call Broker'),
                    onPressed: () {
                      // You can add url_launcher later
                    },
                  ),

                const SizedBox(height: 20),

                const Divider(),

                /// Broker Properties
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Properties by Broker',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('properties')
                      .where('uploadedBy', isEqualTo: brokerId)
                      .where('verificationStatus', isEqualTo: 'approved')
                      .snapshots(),
                  builder: (context, propertySnap) {
                    if (!propertySnap.hasData) {
                      return const CircularProgressIndicator();
                    }

                    final properties = propertySnap.data!.docs;

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
                        final data =
                            properties[index].data() as Map<String, dynamic>;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: ListTile(
                            title: Text(data['title'] ?? ''),
                            subtitle: Text(
                              '₹${data['price']} • ${data['city']}',
                            ),
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
