import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/services/deal_services.dart';
import 'package:flutter/material.dart';

class BrokerDealsScreen extends StatefulWidget {
  const BrokerDealsScreen({super.key});

  @override
  State<BrokerDealsScreen> createState() => _BrokerDealsScreenState();
}

class _BrokerDealsScreenState extends State<BrokerDealsScreen> {
  String? _updatingDealId;

  Future<void> _updateStatus({
    required String dealId,
    required String status,
    required String successMessage,
  }) async {
    setState(() => _updatingDealId = dealId);
    try {
      await DealServices().updateDealStatus(dealId, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update deal: $e')));
    } finally {
      if (mounted) setState(() => _updatingDealId = null);
    }
  }

  Future<void> _showCounterDialog(String dealId, int initialAmount) async {
    final controller = TextEditingController(text: initialAmount.toString());

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Counter Offer'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Enter counter amount'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final counter = int.tryParse(controller.text.trim());
                if (counter == null || counter <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid counter amount')),
                  );
                  return;
                }

                Navigator.pop(context);
                setState(() => _updatingDealId = dealId);
                try {
                  await DealServices().counterOffer(
                    dealId: dealId,
                    counterAmount: counter,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Counter offer sent')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to send counter offer: $e')),
                  );
                } finally {
                  if (mounted) setState(() => _updatingDealId = null);
                }
              },
              child: const Text('Send Counter'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Deal Requests')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: DealServices().brokerDeals(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Unable to load deals: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final deals = snapshot.data?.docs ?? [];
          if (deals.isEmpty) {
            return const Center(child: Text('No deals'));
          }

          return ListView.builder(
            itemCount: deals.length,
            itemBuilder: (context, index) {
              final doc = deals[index];
              final deal = doc.data();
              final status = (deal['status'] ?? 'pending').toString();
              final counterAmount = deal['counterAmount'];
              final isUpdating = _updatingDealId == doc.id;

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text('Offer: ₹${deal['offerAmount'] ?? 0}'),
                  subtitle: Text(
                    'Status: $status${counterAmount != null ? ' • Counter: ₹$counterAmount' : ''}',
                  ),
                  trailing: isUpdating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'accept') {
                              await _updateStatus(
                                dealId: doc.id,
                                status: 'accepted',
                                successMessage: 'Deal accepted',
                              );
                            } else if (value == 'reject') {
                              await _updateStatus(
                                dealId: doc.id,
                                status: 'rejected',
                                successMessage: 'Deal rejected',
                              );
                            } else if (value == 'counter') {
                              final start = (deal['offerAmount'] as num?)?.toInt() ?? 0;
                              await _showCounterDialog(doc.id, start);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'accept', child: Text('Accept')),
                            PopupMenuItem(value: 'counter', child: Text('Counter Offer')),
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
