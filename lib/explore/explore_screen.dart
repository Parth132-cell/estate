import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/explore/explore_bottom_sheet.dart';
import 'package:flutter/material.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  void _openFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ExploreFilterSheet(
        selectedBhk: selectedBhk,
        maxBudget: maxBudget,
        onApply: (bhk, budget) {
          setState(() {
            selectedBhk = bhk;
            maxBudget = budget;
          });
        },
      ),
    );
  }

  int? selectedBhk;
  int? maxBudget;

  String searchText = '';

  Query get _baseQuery {
    Query ref = FirebaseFirestore.instance
        .collection('properties')
        .where('verificationStatus', isEqualTo: 'approved');

    // 🔍 CITY SEARCH MODE
    if (searchText.isNotEmpty) {
      return ref
          .orderBy('city_lower')
          .where('city_lower', isGreaterThanOrEqualTo: searchText)
          .where('city_lower', isLessThanOrEqualTo: '$searchText\uf8ff');
    }

    // 🧩 FILTER MODE
    if (selectedBhk != null) {
      ref = ref.where('bhk', isEqualTo: selectedBhk);
    }

    if (maxBudget != null) {
      ref = ref.where('price', isLessThanOrEqualTo: maxBudget);
    }

    return ref.orderBy('createdAt', descending: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Column(
          children: [
            // 🔍 Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    searchText = value.toLowerCase().trim();
                    if (searchText.isNotEmpty) {
                      maxBudget = null;
                    }
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search by city',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            // 🧩 Filter Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // BHK Filter
                  FilterChip(
                    label: Text(
                      selectedBhk == null ? 'BHK' : '${selectedBhk} BHK',
                    ),
                    selected: selectedBhk != null,
                    onSelected: (_) {
                      _openFilterSheet(context);
                    },
                  ),

                  const SizedBox(width: 8),

                  // Budget Filter
                  FilterChip(
                    label: Text(
                      maxBudget == null
                          ? 'Budget'
                          : '≤ ₹${maxBudget! ~/ 100000} L',
                    ),
                    selected: maxBudget != null,
                    onSelected: searchText.isNotEmpty
                        ? null // 🔒 disable during search
                        : (_) {
                            _openFilterSheet(context);
                          },
                  ),

                  const Spacer(),

                  // Clear Filters
                  if (selectedBhk != null ||
                      maxBudget != null ||
                      searchText.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          searchText = '';
                          selectedBhk = null;
                          maxBudget = null;
                        });
                      },
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ),

            // 📊 Results
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _baseQuery.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No properties found'));
                  }

                  final docs = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['title'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${data['city']} • ${data['bhk']} BHK',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '₹${data['price']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
