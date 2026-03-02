import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/services/lead_services.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BrokerLeadsScreen extends StatelessWidget {
  const BrokerLeadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Color getPriorityColor(String priority) {
      switch (priority) {
        case 'hot':
          return Colors.red;
        case 'warm':
          return Colors.orange;
        case 'cold':
          return Colors.blue;
        default:
          return Colors.grey;
      }
    }

    final brokerId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text("My Leads")),
      body: StreamBuilder<QuerySnapshot>(
        stream: LeadService().brokerLeads(brokerId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final leads = snapshot.data!.docs;

          if (leads.isEmpty) {
            return const Center(child: Text("No leads yet"));
          }

          return ListView.builder(
            itemCount: leads.length,
            itemBuilder: (context, index) {
              final doc = leads[index];
              final data = leads[index].data() as Map<String, dynamic>;

              return ListTile(
                title: Text("Property: ${data['propertyId']}"),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Status: ${data['status']}"),
                    Row(
                      children: [
                        const Text("Priority: "),
                        Chip(
                          label: Text(data['priority'] ?? 'warm'),
                          backgroundColor: getPriorityColor(
                            data['priority'] ?? 'warm',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'contacted') {
                      LeadService().markContacted(doc.id);
                    } else if (value == 'hot' ||
                        value == 'warm' ||
                        value == 'cold') {
                      LeadService().updatePriority(doc.id, value);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'contacted',
                      child: Text('Mark Contacted'),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 'hot', child: Text('Hot')),
                    PopupMenuItem(value: 'warm', child: Text('Warm')),
                    PopupMenuItem(value: 'cold', child: Text('Cold')),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
