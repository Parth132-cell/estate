import 'package:estatex_app/payments/escrow_service.dart';
import 'package:estatex_app/agreements/agreement_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminEscrowScreen extends StatelessWidget {
  const AdminEscrowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Escrow Management")),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('escrow')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No escrow transactions"));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text("Deal ID: ${data['dealId']}"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Buyer: ${data['buyerId']}"),
                      Text("Amount: ₹${data['amount']}"),
                      Text("Status: ${data['status']}"),
                    ],
                  ),
                  trailing: data['status'] == 'payment_pending'
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            /// ✅ RELEASE FUNDS + CREATE AGREEMENT
                            IconButton(
                              icon: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                              tooltip: "Release Funds",
                              onPressed: () async {
                                try {
                                  // 1️⃣ Release escrow
                                  await EscrowService().release(doc.id);

                                  // 2️⃣ Fetch deal details
                                  final dealSnap = await FirebaseFirestore
                                      .instance
                                      .collection('deals')
                                      .doc(data['dealId'])
                                      .get();

                                  final dealData = dealSnap.data();
                                  if (dealData == null) return;

                                  final dealBuyerId = dealData['buyerId'];
                                  final dealBrokerId = dealData['brokerId'];

                                  // 3️⃣ Create agreement
                                  await AgreementService().createAgreement(
                                    dealId: data['dealId'],
                                    buyerId: dealBuyerId,
                                    brokerId: dealBrokerId,
                                  );

                                  // 4️⃣ Feedback
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Escrow completed & agreement created",
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Error: ${e.toString()}"),
                                    ),
                                  );
                                }
                              },
                            ),

                            /// 🔁 REFUND BUYER
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              tooltip: "Refund Buyer",
                              onPressed: () async {
                                await EscrowService().refund(doc.id);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Escrow cancelled"),
                                  ),
                                );
                              },
                            ),
                          ],
                        )
                      : Chip(
                          label: Text(data['status']),
                          backgroundColor: data['status'] == 'completed'
                              ? Colors.green
                              : Colors.orange,
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
