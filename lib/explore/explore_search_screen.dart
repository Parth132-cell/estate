import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/colors.dart';
import 'package:estatex_app/property/add_property/property_type_selector.dart';
import 'package:estatex_app/property/property_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExploreSearchScreen extends StatefulWidget {
  final String? initialCategory;
  final String? initialCity;

  const ExploreSearchScreen({
    super.key,
    this.initialCategory,
    this.initialCity,
  });

  @override
  State<ExploreSearchScreen> createState() => _ExploreSearchScreenState();
}

class _ExploreSearchScreenState extends State<ExploreSearchScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  String? _selectedCategory;
  String _searchQuery = '';
  String _sortBy = 'newest'; // newest | price_asc | price_desc
  int? _minPrice;
  int? _maxPrice;
  int? _bhk;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    if (widget.initialCity != null) {
      _searchCtrl.text = widget.initialCity!;
      _searchQuery = widget.initialCity!.toLowerCase();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // Build Firestore query based on filters
  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('properties')
        .where('verificationStatus', isEqualTo: 'approved');

    if (_selectedCategory != null) {
      q = q.where('propertyCategory', isEqualTo: _selectedCategory);
    }
    if (_bhk != null) {
      q = q.where('bhk', isEqualTo: _bhk);
    }

    switch (_sortBy) {
      case 'price_asc':
        q = q.orderBy('price', descending: false);
        break;
      case 'price_desc':
        q = q.orderBy('price', descending: true);
        break;
      default:
        q = q.orderBy('createdAt', descending: true);
    }

    return q.limit(80);
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    final title = (data['title'] ?? '').toString().toLowerCase();
    final city = (data['city'] ?? '').toString().toLowerCase();
    final locality = (data['locality'] ?? '').toString().toLowerCase();
    return title.contains(q) || city.contains(q) || locality.contains(q);
  }

  bool _matchesPrice(Map<String, dynamic> data) {
    final price = (data['price'] as num?)?.toInt() ?? 0;
    if (_minPrice != null && price < _minPrice!) return false;
    if (_maxPrice != null && price > _maxPrice!) return false;
    return true;
  }

  int get _activeFilterCount {
    int c = 0;
    if (_selectedCategory != null) c++;
    if (_bhk != null) c++;
    if (_minPrice != null || _maxPrice != null) c++;
    if (_sortBy != 'newest') c++;
    return c;
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = null;
      _bhk = null;
      _minPrice = null;
      _maxPrice = null;
      _sortBy = 'newest';
      _searchQuery = '';
      _searchCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _SearchBar(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            onClear: () => setState(() => _searchQuery = ''),
          ),
        ),
        actions: [
          // Filter button with badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.tune_outlined),
                tooltip: 'Filters',
                onPressed: () => setState(() => _showFilters = !_showFilters),
              ),
              if (_activeFilterCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$_activeFilterCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Category filter chips ──
          const SizedBox(height: 8),
          ExploreCategoryFilter(
            selectedCategory: _selectedCategory,
            onSelect: (cat) => setState(() => _selectedCategory = cat),
          ),
          const SizedBox(height: 8),

          // ── Expanded filters panel ──
          if (_showFilters)
            _FiltersPanel(
              sortBy: _sortBy,
              bhk: _bhk,
              minPrice: _minPrice,
              maxPrice: _maxPrice,
              onSortChanged: (v) => setState(() => _sortBy = v),
              onBhkChanged: (v) => setState(() => _bhk = v),
              onPriceChanged: (min, max) => setState(() {
                _minPrice = min;
                _maxPrice = max;
              }),
              onClear: _clearFilters,
            ),

          // ── Active filter pills ──
          if (_activeFilterCount > 0 && !_showFilters)
            _ActiveFilterPills(
              category: _selectedCategory,
              bhk: _bhk,
              minPrice: _minPrice,
              maxPrice: _maxPrice,
              sortBy: _sortBy,
              onRemoveCategory: () => setState(() => _selectedCategory = null),
              onRemoveBhk: () => setState(() => _bhk = null),
              onRemovePrice: () => setState(() {
                _minPrice = null;
                _maxPrice = null;
              }),
              onRemoveSort: () => setState(() => _sortBy = 'newest'),
            ),

          // ── Results ──
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _buildQuery().snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final allDocs = snapshot.data?.docs ?? [];
                final filtered = allDocs
                    .where(
                      (d) =>
                          _matchesSearch(d.data()) && _matchesPrice(d.data()),
                    )
                    .toList();

                if (filtered.isEmpty) {
                  return _EmptyResults(
                    hasFilters:
                        _activeFilterCount > 0 || _searchQuery.isNotEmpty,
                    onClear: _clearFilters,
                  );
                }

                return Column(
                  children: [
                    // Results count bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: Colors.white,
                      child: Row(
                        children: [
                          Text(
                            '${filtered.length} properties found',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          _SortButton(
                            sortBy: _sortBy,
                            onChanged: (v) => setState(() => _sortBy = v),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // Property list
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final doc = filtered[index];
                          return _ExplorePropertyCard(
                            docId: doc.id,
                            data: doc.data(),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// SEARCH BAR
// ─────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          hintText: 'Search city, locality, property…',
          hintStyle: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
          prefixIcon: const Icon(
            Icons.search,
            size: 18,
            color: AppColors.textSecondary,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () {
                    controller.clear();
                    onClear();
                  },
                )
              : null,
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// FILTERS PANEL
// ─────────────────────────────────────────

class _FiltersPanel extends StatelessWidget {
  final String sortBy;
  final int? bhk;
  final int? minPrice;
  final int? maxPrice;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<int?> onBhkChanged;
  final void Function(int?, int?) onPriceChanged;
  final VoidCallback onClear;

  const _FiltersPanel({
    required this.sortBy,
    required this.bhk,
    required this.minPrice,
    required this.maxPrice,
    required this.onSortChanged,
    required this.onBhkChanged,
    required this.onPriceChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sort
          const Text(
            'Sort by',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _FilterChipItem(
                label: 'Newest',
                selected: sortBy == 'newest',
                onTap: () => onSortChanged('newest'),
              ),
              _FilterChipItem(
                label: 'Price ↑',
                selected: sortBy == 'price_asc',
                onTap: () => onSortChanged('price_asc'),
              ),
              _FilterChipItem(
                label: 'Price ↓',
                selected: sortBy == 'price_desc',
                onTap: () => onSortChanged('price_desc'),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // BHK
          const Text(
            'BHK',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _FilterChipItem(
                label: 'Any',
                selected: bhk == null,
                onTap: () => onBhkChanged(null),
              ),
              for (final b in [1, 2, 3, 4, 5])
                _FilterChipItem(
                  label: '$b BHK',
                  selected: bhk == b,
                  onTap: () => onBhkChanged(bhk == b ? null : b),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Price range
          const Text(
            'Price range',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PriceChip(
                label: 'Under ₹50L',
                selected: maxPrice == 5000000 && minPrice == null,
                onTap: () => onPriceChanged(null, 5000000),
              ),
              _PriceChip(
                label: '₹50L–1Cr',
                selected: minPrice == 5000000 && maxPrice == 10000000,
                onTap: () => onPriceChanged(5000000, 10000000),
              ),
              _PriceChip(
                label: '₹1Cr–3Cr',
                selected: minPrice == 10000000 && maxPrice == 30000000,
                onTap: () => onPriceChanged(10000000, 30000000),
              ),
              _PriceChip(
                label: 'Above ₹3Cr',
                selected: minPrice == 30000000 && maxPrice == null,
                onTap: () => onPriceChanged(30000000, null),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Clear all
          GestureDetector(
            onTap: onClear,
            child: const Text(
              'Clear all filters',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _PriceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PriceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.grey.shade200,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// ACTIVE FILTER PILLS
// ─────────────────────────────────────────

class _ActiveFilterPills extends StatelessWidget {
  final String? category;
  final int? bhk;
  final int? minPrice;
  final int? maxPrice;
  final String sortBy;
  final VoidCallback onRemoveCategory;
  final VoidCallback onRemoveBhk;
  final VoidCallback onRemovePrice;
  final VoidCallback onRemoveSort;

  const _ActiveFilterPills({
    required this.category,
    required this.bhk,
    required this.minPrice,
    required this.maxPrice,
    required this.sortBy,
    required this.onRemoveCategory,
    required this.onRemoveBhk,
    required this.onRemovePrice,
    required this.onRemoveSort,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          if (category != null)
            _Pill(
              label: PropertyCategory.fromKey(category!).label,
              onRemove: onRemoveCategory,
            ),
          if (bhk != null) _Pill(label: '$bhk BHK', onRemove: onRemoveBhk),
          if (minPrice != null || maxPrice != null)
            _Pill(label: _priceLabel(), onRemove: onRemovePrice),
          if (sortBy != 'newest')
            _Pill(
              label: sortBy == 'price_asc' ? 'Price ↑' : 'Price ↓',
              onRemove: onRemoveSort,
            ),
        ],
      ),
    );
  }

  String _priceLabel() {
    if (minPrice != null && maxPrice != null) {
      return '${_fmt(minPrice!)}–${_fmt(maxPrice!)}';
    }
    if (minPrice != null) return 'Above ${_fmt(minPrice!)}';
    if (maxPrice != null) return 'Under ${_fmt(maxPrice!)}';
    return 'Price';
  }

  String _fmt(int v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(0)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(0)}L';
    return '$v';
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _Pill({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// SORT BUTTON
// ─────────────────────────────────────────

class _SortButton extends StatelessWidget {
  final String sortBy;
  final ValueChanged<String> onChanged;

  const _SortButton({required this.sortBy, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (_) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Sort by',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                for (final (key, label) in [
                  ('newest', 'Newest first'),
                  ('price_asc', 'Price: Low to High'),
                  ('price_desc', 'Price: High to Low'),
                ])
                  ListTile(
                    title: Text(label),
                    trailing: sortBy == key
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () => Navigator.pop(context, key),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
        if (result != null) onChanged(result);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sort, size: 16, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            sortBy == 'price_asc'
                ? 'Price ↑'
                : sortBy == 'price_desc'
                ? 'Price ↓'
                : 'Newest',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// EXPLORE PROPERTY CARD
// ─────────────────────────────────────────

class _ExplorePropertyCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  const _ExplorePropertyCard({required this.docId, required this.data});

  String _fmt(int v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)} Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)} L';
    return '₹${NumberFormat('#,##,###').format(v)}';
  }

  @override
  Widget build(BuildContext context) {
    final images = (data['images'] as List? ?? [])
        .map((e) => e.toString())
        .toList();
    final title = (data['title'] ?? '').toString();
    final city = (data['city'] ?? '').toString();
    final locality = (data['locality'] ?? '').toString();
    final price = (data['price'] as num?)?.toInt() ?? 0;
    final bhk = (data['bhk'] as num?)?.toInt() ?? 0;
    final area = (data['areaSqft'] as num?)?.toInt() ?? 0;
    final category = (data['propertyCategory'] ?? 'apartment').toString();
    final cat = PropertyCategory.fromKey(category);
    final isVerified = data['verificationStatus'] == 'approved';
    final isFeatured = data['isFeatured'] == true;
    final listingType = (data['listingType'] ?? 'individual').toString();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PropertyDetailsScreen(
            propertyId: docId,
            imageUrl: images.isNotEmpty ? images.first : '',
            imageUrls: images,
            price: price > 0 ? _fmt(price) : 'Price on request',
            title: title,
            location: city,
            bhk: bhk > 0 ? '$bhk BHK' : '',
            brokerId: (data['uploadedBy'] ?? '').toString(),
            verified: isVerified,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: isFeatured
              ? Border.all(color: Colors.orange.shade300, width: 1.5)
              : Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                  child: images.isNotEmpty
                      ? Image.network(
                          images.first,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                ),

                // Top badges
                Positioned(
                  top: 10,
                  left: 10,
                  child: Row(
                    children: [
                      // Category badge
                      _ImgBadge(label: cat.label, color: cat.group.color),
                      if (isFeatured) ...[
                        const SizedBox(width: 6),
                        _ImgBadge(
                          label: '⭐ Featured',
                          color: Colors.orange.shade700,
                        ),
                      ],
                    ],
                  ),
                ),

                // Verified badge
                if (isVerified)
                  const Positioned(
                    top: 10,
                    right: 10,
                    child: _ImgBadge(label: '✓ Verified', color: Colors.green),
                  ),

                // Listing type
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      listingType == 'professional' ? 'Broker' : 'Owner',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Price
                  Text(
                    price > 0 ? _fmt(price) : 'Price on request',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 3),

                  // Title
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),

                  // Location
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          locality.isNotEmpty ? '$locality, $city' : city,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Stats row
                  Row(
                    children: [
                      if (bhk > 0 && cat.hasBhk) ...[
                        _StatChip(icon: Icons.bed_outlined, label: '$bhk BHK'),
                        const SizedBox(width: 8),
                      ],
                      if (area > 0) ...[
                        _StatChip(
                          icon: Icons.square_foot_outlined,
                          label: '$area sqft',
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (area > 0 && price > 0)
                        _StatChip(
                          icon: Icons.currency_rupee,
                          label: '${(price / area).round()}/sqft',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    height: 180,
    width: double.infinity,
    color: Colors.grey.shade200,
    child: const Icon(Icons.home_outlined, color: Colors.grey, size: 48),
  );
}

class _ImgBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _ImgBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// EMPTY RESULTS
// ─────────────────────────────────────────

class _EmptyResults extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClear;

  const _EmptyResults({required this.hasFilters, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters
                  ? 'No properties match your filters'
                  : 'No properties yet',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Try changing your search or removing filters.'
                  : 'Properties will appear here once listed.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (hasFilters) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onClear,
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
