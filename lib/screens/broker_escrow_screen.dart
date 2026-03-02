import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/payments/escrow_service.dart';
import 'package:flutter/material.dart';

class BrokerEscrowScreen extends StatelessWidget {
  const BrokerEscrowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Escrow Management"),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Reconcile payments',
            onPressed: () async {
              try {
                final updated = await EscrowService().reconcilePendingEscrows();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Reconciled $updated escrow record(s)')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Reconcile failed: $e')));
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: EscrowService().brokerEscrow(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final escrows = snapshot.data!.docs;

          if (escrows.isEmpty) {
            return const Center(child: Text("No escrow records"));
          }

          return ListView.builder(
            itemCount: escrows.length,
            itemBuilder: (context, index) {
              final data = escrows[index].data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text("Amount: ₹${data['amount'] ?? 0}"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Status: ${data['status'] ?? 'unknown'}"),
                      Text(
                        "Payment: ${data['paymentStatus'] ?? 'unknown'} • Txn: ${data['transactionId'] ?? '-'}",
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'release') {
                        EscrowService().release(escrows[index].id);
                      } else {
                        EscrowService().refund(escrows[index].id);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'release', child: Text('Release')),
                      PopupMenuItem(value: 'refund', child: Text('Refund')),
                    ],
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
