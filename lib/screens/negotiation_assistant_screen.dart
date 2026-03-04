import 'package:estatex_app/services/negotiation_assistant_service.dart';
import 'package:flutter/material.dart';

class NegotiationAssistantScreen extends StatefulWidget {
  final int? listedPrice;
  final int? offerPrice;

  const NegotiationAssistantScreen({
    super.key,
    this.listedPrice,
    this.offerPrice,
  });

  @override
  State<NegotiationAssistantScreen> createState() => _NegotiationAssistantScreenState();
}

class _NegotiationAssistantScreenState extends State<NegotiationAssistantScreen> {
  final listedCtrl = TextEditingController();
  final offerCtrl = TextEditingController();
  final counterCtrl = TextEditingController();
  Map<String, dynamic>? result;

  @override
  void initState() {
    super.initState();
    if (widget.listedPrice != null) {
      listedCtrl.text = widget.listedPrice.toString();
    }
    if (widget.offerPrice != null) {
      offerCtrl.text = widget.offerPrice.toString();
    }
  }

  @override
  void dispose() {
    listedCtrl.dispose();
    offerCtrl.dispose();
    counterCtrl.dispose();
    super.dispose();
  }

  void runAssistant() {
    final listed = int.tryParse(listedCtrl.text.trim());
    final offer = int.tryParse(offerCtrl.text.trim());
    final counter = int.tryParse(counterCtrl.text.trim());

    if (listed == null || offer == null || listed <= 0 || offer <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid listed and offer prices')),
      );
      return;
    }

    setState(() {
      result = NegotiationAssistantService().suggest(
        listedPrice: listed,
        offerPrice: offer,
        counterPrice: counter,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Negotiation Assistant')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: listedCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Listed Price'),
          ),
          TextField(
            controller: offerCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Offer Price'),
          ),
          TextField(
            controller: counterCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Current Counter (optional)'),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: runAssistant,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Get Suggestion'),
          ),
          if (result != null) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Strategy: ${result!['strategy']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Suggested Counter: ₹${result!['suggestedCounter']}'),
                    Text('Gap: ₹${result!['gap']}'),
                    const SizedBox(height: 8),
                    Text(result!['message'].toString()),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
