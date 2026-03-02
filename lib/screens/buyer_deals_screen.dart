import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/payments/escrow_service.dart';
import 'package:estatex_app/services/deal_services.dart';
import 'package:flutter/material.dart';

class BuyerDealsScreen extends StatelessWidget {
  const BuyerDealsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Offers")),
      body: StreamBuilder<QuerySnapshot>(
        stream: DealServices().buyerDeals(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final deals = snapshot.data!.docs;

          if (deals.isEmpty) {
            return const Center(child: Text("No offers yet"));
          }

          return ListView.builder(
            itemCount: deals.length,
            itemBuilder: (context, index) {
              final doc = deals[index];
              final deal = doc.data() as Map<String, dynamic>;
              final dealId = doc.id;

              return Card(
                margin: const EdgeInsets.all(10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Offer: ₹${deal['offerAmount']}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text("Status: ${deal['status']}"),

                      if (deal['counterAmount'] != null)
                        Text("Counter: ₹${deal['counterAmount']}"),

                      /// 🔐 PAY TOKEN BUTTON (ONLY IF ACCEPTED)
                      if (deal['status'] == 'accepted') ...[
                        const SizedBox(height: 10),
                        ElevatedButton(
                          child: const Text("Pay Token (10%)"),
                          onPressed: () async {
                            final offerAmount = (deal['offerAmount'] as num)
                                .toDouble();
                            final tokenAmount = (offerAmount * 0.1).toInt();

                            await EscrowService().createEscrow(
                              dealId: dealId,
                              propertyId: deal['propertyId'],
                              brokerId: deal['brokerId'],
                              amount: tokenAmount,
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Token amount held in escrow"),
                              ),
                            );
                          },
                        ),
                      ],
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
