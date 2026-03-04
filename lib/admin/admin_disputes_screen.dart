import 'package:estatex_app/services/dispute_service.dart';
import 'package:flutter/material.dart';

class AdminDisputesScreen extends StatelessWidget {
  const AdminDisputesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dispute Resolution')),
      body: StreamBuilder(
        stream: DisputeService().disputes(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No disputes raised'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text('Deal: ${data['dealId'] ?? '-'}'),
                  subtitle: Text('Reason: ${data['reason'] ?? '-'}\nStatus: ${data['status'] ?? 'open'}'),
                  trailing: data['status'] == 'resolved'
                      ? const Chip(label: Text('Resolved'))
                      : TextButton(
                          child: const Text('Resolve'),
                          onPressed: () async {
                            await DisputeService().resolve(
                              disputeId: doc.id,
                              resolution: 'Resolved by admin',
                            );
                          },
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
