import 'package:flutter/material.dart';

class ExploreFilterSheet extends StatefulWidget {
  final int? selectedBhk;
  final int? maxBudget;
  final void Function(int? bhk, int? budget) onApply;

  const ExploreFilterSheet({
    super.key,
    required this.selectedBhk,
    required this.maxBudget,
    required this.onApply,
  });

  @override
  State<ExploreFilterSheet> createState() => _ExploreFilterSheetState();
}

class _ExploreFilterSheetState extends State<ExploreFilterSheet> {
  int? bhk;
  int? budget;

  @override
  void initState() {
    super.initState();
    bhk = widget.selectedBhk;
    budget = widget.maxBudget;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filters',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 16),

          const Text('BHK'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [1, 2, 3, 4].map((v) {
              final selected = bhk == v;
              return ChoiceChip(
                label: Text('$v BHK'),
                selected: selected,
                onSelected: (_) {
                  setState(() {
                    bhk = selected ? null : v;
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          const Text('Max Budget'),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: budget,
            items: const [
              DropdownMenuItem(value: 3000000, child: Text('₹30 Lakh')),
              DropdownMenuItem(value: 5000000, child: Text('₹50 Lakh')),
              DropdownMenuItem(value: 7500000, child: Text('₹75 Lakh')),
              DropdownMenuItem(value: 10000000, child: Text('₹1 Cr')),
            ],
            onChanged: (v) => setState(() => budget = v),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              TextButton(
                onPressed: () {
                  widget.onApply(null, null);
                  Navigator.pop(context);
                },
                child: const Text('Clear'),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  widget.onApply(bhk, budget);
                  Navigator.pop(context);
                },
                child: const Text('Apply'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
