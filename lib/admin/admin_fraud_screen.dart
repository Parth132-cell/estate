import 'package:estatex_app/services/fraud_detection_service.dart';
import 'package:flutter/material.dart';

class AdminFraudScreen extends StatelessWidget {
  const AdminFraudScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fraud Detection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add_check_circle_outlined),
            tooltip: 'Run Scan',
            onPressed: () async {
              final count = await FraudDetectionService().scanAndCreateAlerts();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Scan complete. $count alert(s) created.')),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder(
        stream: FraudDetectionService().alerts(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No fraud alerts')); 
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final status = (data['status'] ?? 'open').toString();

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text('${data['entityType']} • ${data['entityId']}'),
                  subtitle: Text('Reason: ${data['reason']}\nSeverity: ${data['severity']}'),
                  trailing: status == 'resolved'
                      ? const Chip(label: Text('Resolved'))
                      : TextButton(
                          onPressed: () => FraudDetectionService().resolveAlert(doc.id),
                          child: const Text('Resolve'),
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
