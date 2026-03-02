import 'package:estatex_app/services/deal_services.dart';
import 'package:flutter/material.dart';

class BrokerDealsScreen extends StatelessWidget {
  const BrokerDealsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Deal Requests")),
      body: StreamBuilder(
        stream: DealServices().brokerDeals(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final deals = snapshot.data!.docs;

          if (deals.isEmpty) {
            return const Center(child: Text("No deals"));
          }
          return ListView.builder(
            itemBuilder: (context, index) {
              final deal = deals[index].data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text("Offer: ₹${deal['offerAmount']}"),
                  subtitle: Text("Status: ${deal['status']}"),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'accept') {
                        await DealServices().updateDealStatus(
                          deals[index].id,
                          'accepted',
                        );
                      } else if (value == 'reject') {
                        await DealServices().updateDealStatus(
                          deals[index].id,
                          'rejected',
                        );
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'accept', child: Text('Accept')),
                      PopupMenuItem(value: 'reject', child: Text('Reject')),
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
