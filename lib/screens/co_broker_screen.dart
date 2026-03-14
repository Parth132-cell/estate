import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/services/co_broker_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CoBrokerScreen extends StatelessWidget {
  const CoBrokerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please login')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Co-broker Collaboration')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('deals')
            .where('brokerId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No deals available for co-broker assignment'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final split = (data['coBrokerSplitPercent'] ?? 0).toString();

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text('Deal: ${doc.id.substring(0, 6)}'),
                  subtitle: Text(
                    'Co-broker: ${data['coBrokerId'] ?? '-'}\n'
                    'Split: $split% | Status: ${data['coBrokerStatus'] ?? 'not_assigned'}',
                  ),
                  trailing: TextButton(
                    child: const Text('Assign'),
                    onPressed: () => _openAssignDialog(context, doc.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openAssignDialog(BuildContext context, String dealId) async {
    final brokerCtrl = TextEditingController();
    final splitCtrl = TextEditingController(text: '20');

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Assign Co-broker'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: brokerCtrl,
              decoration: const InputDecoration(labelText: 'Co-broker UID'),
            ),
            TextField(
              controller: splitCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Split %'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final split = int.tryParse(splitCtrl.text.trim()) ?? 0;
              if (brokerCtrl.text.trim().isEmpty || split <= 0 || split >= 100) {
                return;
              }
              await CoBrokerService().assignCoBroker(
                dealId: dealId,
                coBrokerId: brokerCtrl.text.trim(),
                splitPercent: split,
              );
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }
}
