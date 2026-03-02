import 'package:flutter/material.dart';

class FeaturePlansSheet extends StatelessWidget {
  const FeaturePlansSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Boost your property',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          const Text(
            'Get more visibility and faster responses',
            style: TextStyle(color: Colors.grey),
          ),

          const SizedBox(height: 20),

          _PlanTile(
            title: '3 Days Boost',
            price: '₹99',
            subtitle: 'Quick visibility boost',
          ),
          _PlanTile(
            title: '7 Days Boost',
            price: '₹199',
            subtitle: 'Most popular choice',
            popular: true,
          ),
          _PlanTile(
            title: '30 Days Boost',
            price: '₹499',
            subtitle: 'Maximum exposure',
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Payments coming soon. Contact admin to feature.',
                    ),
                  ),
                );
                Navigator.pop(context);
              },
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  final String title;
  final String price;
  final String subtitle;
  final bool popular;

  const _PlanTile({
    required this.title,
    required this.price,
    required this.subtitle,
    this.popular = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: popular ? Colors.blue : Colors.grey.shade300,
          width: popular ? 1.5 : 1,
        ),
        color: popular ? Colors.blue.withOpacity(0.05) : Colors.white,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (popular)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'POPULAR',
                          style: TextStyle(fontSize: 10, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Text(
            price,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
