import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/payments/escrow_service.dart';
import 'package:flutter/material.dart';

class BrokerEscrowScreen extends StatelessWidget {
  const BrokerEscrowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Escrow Management")),
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
                  title: Text("Amount: ₹${data['amount']}"),
                  subtitle: Text("Status: ${data['status']}"),
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
