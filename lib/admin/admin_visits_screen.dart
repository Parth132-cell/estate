import 'package:estatex_app/services/visit_schedule_service.dart';
import 'package:flutter/material.dart';

class AdminVisitsScreen extends StatelessWidget {
  const AdminVisitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Visit Monitoring')),
      body: StreamBuilder(
        stream: VisitScheduleService().allVisits(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No visit requests found'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text('Property: ${data['propertyId'] ?? '-'}'),
                  subtitle: Text('Buyer: ${data['buyerId'] ?? '-'}\nBroker: ${data['brokerId'] ?? '-'}\nStatus: ${data['status'] ?? 'requested'}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
