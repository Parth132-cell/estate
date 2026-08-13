import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/colors.dart';
import 'package:estatex_app/explore/explore_search_screen.dart';
import 'package:estatex_app/property/property_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  // Max 3 properties for comparison
  final List<String> _propertyIds = [];
  final Map<String, Map<String, dynamic>> _cache = {};

  Future<void> _addProperty() async {
    if (_propertyIds.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 3 properties can be compared'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Open explore to pick a property
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _PropertyPickerSheet(),
    );

    if (result != null && !_propertyIds.contains(result)) {
      final snap = await FirebaseFirestore.instance
          .collection('properties')
          .doc(result)
          .get();
      if (snap.exists) {
        setState(() {
          _propertyIds.add(result);
          _cache[result] = snap.data()!;
        });
      }
    }
  }

  void _remove(String id) {
    setState(() => _propertyIds.remove(id));
  }

  String _fmt(int v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)} Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)} L';
    return '₹${NumberFormat('#,##,###').format(v)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Compare Properties'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_propertyIds.isNotEmpty)
            TextButton(
              onPressed: () => setState(() {
                _propertyIds.clear();
                _cache.clear();
              }),
              child: const Text('Clear all'),
            ),
        ],
      ),
      body: _propertyIds.isEmpty
          ? _EmptyCompare(onAdd: _addProperty)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Property cards row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Labels column
                      const _LabelsColumn(),
                      // Property columns
                      ...(_propertyIds.map((id) {
                        final data = _cache[id] ?? {};
                        return Expanded(
                          child: _PropertyColumn(
                            propertyId: id,
                            data: data,
                            onRemove: () => _remove(id),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PropertyDetailsScreen(
                                  propertyId: id,
                                  imageUrl:
                                      ((data['images'] as List? ?? [])
                                          .isNotEmpty
                                      ? (data['images'] as List).first
                                            .toString()
                                      : ''),
                                  imageUrls: (data['images'] as List? ?? [])
                                      .map((e) => e.toString())
                                      .toList(),
                                  price: _fmt(
                                    (data['price'] as num?)?.toInt() ?? 0,
                                  ),
                                  title: data['title']?.toString() ?? '',
                                  location: data['city']?.toString() ?? '',
                                  bhk:
                                      '${(data['bhk'] as num?)?.toInt() ?? 0} BHK',
                                  brokerId:
                                      data['uploadedBy']?.toString() ?? '',
                                  verified:
                                      data['verificationStatus'] == 'approved',
                                ),
                              ),
                            ),
                          ),
                        );
                      })),
                      // Add slot
                      if (_propertyIds.length < 3)
                        Expanded(child: _AddSlot(onAdd: _addProperty)),
                    ],
                  ),
                ],
              ),
            ),
      floatingActionButton: _propertyIds.isNotEmpty && _propertyIds.length < 3
          ? FloatingActionButton.extended(
              onPressed: _addProperty,
              icon: const Icon(Icons.add),
              label: const Text('Add property'),
            )
          : null,
    );
  }
}

// ── Labels Column ──────────────────────────────────────────────────────────

class _LabelsColumn extends StatelessWidget {
  const _LabelsColumn();

  static const _labels = [
    'Photo',
    'Price',
    'BHK',
    'Area',
    'Category',
    'Verified',
    'Listed by',
    'City',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Column(
        children: _labels
            .map(
              (l) => Container(
                height: l == 'Photo' ? 110 : 52,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  l,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ── Property Column ──────────────────────────────────────────────────────────

class _PropertyColumn extends StatelessWidget {
  final String propertyId;
  final Map<String, dynamic> data;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _PropertyColumn({
    required this.propertyId,
    required this.data,
    required this.onRemove,
    required this.onTap,
  });

  String _fmt(int v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(0)}L';
    return '₹$v';
  }

  @override
  Widget build(BuildContext context) {
    final images = (data['images'] as List? ?? [])
        .map((e) => e.toString())
        .toList();
    final price = (data['price'] as num?)?.toInt() ?? 0;
    final bhk = (data['bhk'] as num?)?.toInt() ?? 0;
    final area = (data['areaSqft'] as num?)?.toInt() ?? 0;
    final category = (data['propertyCategory'] ?? 'apartment').toString();
    final verified = data['verificationStatus'] == 'approved';
    final listingType = (data['listingType'] ?? 'individual').toString();
    final city = (data['city'] ?? '-').toString();
    final title = (data['title'] ?? '').toString();

    final cells = [
      // Photo
      GestureDetector(
        onTap: onTap,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: images.isNotEmpty
                  ? Image.network(
                      images.first,
                      height: 100,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
      // Price
      Text(
        price > 0 ? _fmt(price) : '-',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
      // BHK
      Text(bhk > 0 ? '$bhk BHK' : '-', style: const TextStyle(fontSize: 13)),
      // Area
      Text(area > 0 ? '$area sqft' : '-', style: const TextStyle(fontSize: 13)),
      // Category
      Text(_catLabel(category), style: const TextStyle(fontSize: 13)),
      // Verified
      Icon(
        verified ? Icons.verified : Icons.cancel_outlined,
        color: verified ? Colors.green : Colors.grey,
        size: 20,
      ),
      // Listed by
      Text(
        listingType == 'professional' ? 'Broker' : 'Owner',
        style: TextStyle(
          fontSize: 13,
          color: listingType == 'professional'
              ? const Color(0xFF7C3AED)
              : Colors.green.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
      // City
      Text(
        city,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
    ];

    final heights = [110.0, 52.0, 52.0, 52.0, 52.0, 52.0, 52.0, 52.0];

    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Column(
        children: List.generate(cells.length, (i) {
          return Container(
            height: heights[i],
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: cells[i],
          );
        }),
      ),
    );
  }

  Widget _placeholder() => Container(
    height: 100,
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(Icons.home_outlined, color: Colors.grey),
  );

  String _catLabel(String cat) {
    const m = {
      'apartment': 'Apartment',
      'house': 'House',
      'villa': 'Villa',
      'residential_plot': 'Plot',
      'agricultural_land': 'Land',
      'office_space': 'Office',
      'commercial': 'Commercial',
      'pg_hostel': 'PG',
      'flat_rent': 'Rental',
    };
    return m[cat] ?? cat;
  }
}

// ── Add Slot ──────────────────────────────────────────────────────────────────

class _AddSlot extends StatelessWidget {
  final VoidCallback onAdd;
  const _AddSlot({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: GestureDetector(
        onTap: onAdd,
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.primary.withOpacity(0.4),
              style: BorderStyle.solid,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline,
                color: AppColors.primary,
                size: 28,
              ),
              SizedBox(height: 6),
              Text(
                'Add',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Property Picker Sheet ─────────────────────────────────────────────────────

class _PropertyPickerSheet extends StatefulWidget {
  const _PropertyPickerSheet();

  @override
  State<_PropertyPickerSheet> createState() => _PropertyPickerSheetState();
}

class _PropertyPickerSheetState extends State<_PropertyPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Text(
            'Select a property to compare',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by title or city...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('properties')
                  .where('verificationStatus', isEqualTo: 'approved')
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snap) {
                final docs = (snap.data?.docs ?? []).where((d) {
                  if (_query.isEmpty) return true;
                  final title = (d.data()['title'] ?? '')
                      .toString()
                      .toLowerCase();
                  final city = (d.data()['city'] ?? '')
                      .toString()
                      .toLowerCase();
                  return title.contains(_query) || city.contains(_query);
                }).toList();

                if (docs.isEmpty) {
                  return const Center(child: Text('No properties found'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data = docs[i].data();
                    final id = docs[i].id;
                    final price = (data['price'] as num?)?.toInt() ?? 0;
                    return ListTile(
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.home_outlined,
                          color: Colors.grey,
                        ),
                      ),
                      title: Text(
                        data['title']?.toString() ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        '${data['city'] ?? ''} · ${price >= 10000000
                            ? '₹${(price / 10000000).toStringAsFixed(1)}Cr'
                            : price >= 100000
                            ? '₹${(price / 100000).toStringAsFixed(0)}L'
                            : '₹$price'}',
                      ),
                      onTap: () => Navigator.pop(context, id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCompare extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyCompare({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.compare_arrows_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              'Compare properties',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add up to 3 properties to compare side by side — price, area, amenities and more.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add first property'),
            ),
          ],
        ),
      ),
    );
  }
}
