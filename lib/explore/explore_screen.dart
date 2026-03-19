import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/explore/property_listing_repository.dart';
import 'package:estatex_app/property/property_card.dart';
import 'package:estatex_app/property/property_card_skeleton.dart';
import 'package:estatex_app/property/property_details_screen.dart';
import 'package:flutter/material.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _repository = PropertyListingRepository();
  final _scrollController = ScrollController();
  final _cityController = TextEditingController();

  final List<PropertyListing> _listings = [];
  QueryDocumentSnapshot<Map<String, dynamic>>? _lastDocument;

  Timer? _debounce;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isSlowNetwork = false;
  bool _isShowingCachedResults = false;
  bool _hasMore = true;
  String? _error;

  int? _selectedBhk;
  RangeValues _priceRange = const RangeValues(1000000, 10000000);
  bool _priceFilterEnabled = false;

  PropertyFilter get _filter => PropertyFilter(
        city: _cityController.text,
        bhk: _selectedBhk,
        minPrice: _priceFilterEnabled ? _priceRange.start.round() : null,
        maxPrice: _priceFilterEnabled ? _priceRange.end.round() : null,
      );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoadingMore || _isLoading) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  void _onFilterChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _loadInitial);
  }

  Future<void> _loadInitial() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _isSlowNetwork = false;
      _isShowingCachedResults = false;
      _error = null;
      _hasMore = true;
      _lastDocument = null;
    });

    final cached = _repository.getCached(_filter);
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _listings
          ..clear()
          ..addAll(cached);
      });
    } else {
      setState(() => _listings.clear());
    }

    final slowNetworkTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted && _isLoading) {
        setState(() => _isSlowNetwork = true);
      }
    });

    try {
      final result = await _repository.fetchPage(filter: _filter);
      if (!mounted) return;

      setState(() {
        _listings
          ..clear()
          ..addAll(result.items);
        _lastDocument = result.lastDoc;
        _hasMore = result.hasMore;
        _isShowingCachedResults = result.fromCache;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Unable to load properties: $e');
    } finally {
      slowNetworkTimer.cancel();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSlowNetwork = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_lastDocument == null) return;

    setState(() => _isLoadingMore = true);
    try {
      final result = await _repository.fetchPage(
        filter: _filter,
        startAfter: _lastDocument,
      );
      if (!mounted) return;

      setState(() {
        _listings.addAll(result.items);
        _lastDocument = result.lastDoc;
        _hasMore = result.hasMore;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasMore = false;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _clearFilters() {
    _cityController.clear();
    setState(() {
      _selectedBhk = null;
      _priceFilterEnabled = false;
      _priceRange = const RangeValues(1000000, 10000000);
    });
    _onFilterChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Browse Properties')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: TextField(
                controller: _cityController,
                onChanged: (_) => _onFilterChanged(),
                decoration: InputDecoration(
                  hintText: 'Filter by city (exact match)',
                  prefixIcon: const Icon(Icons.location_city_outlined),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: Text(_selectedBhk == null ? 'BHK' : '${_selectedBhk!} BHK'),
                    selected: _selectedBhk != null,
                    onSelected: (_) => _pickBhk(context),
                  ),
                  FilterChip(
                    label: Text(
                      _priceFilterEnabled
                          ? '₹${(_priceRange.start / 100000).round()}L - ₹${(_priceRange.end / 100000).round()}L'
                          : 'Price range',
                    ),
                    selected: _priceFilterEnabled,
                    onSelected: (_) => _pickPriceRange(context),
                  ),
                  if (_selectedBhk != null ||
                      _priceFilterEnabled ||
                      _cityController.text.isNotEmpty)
                    ActionChip(
                      label: const Text('Clear filters'),
                      onPressed: _clearFilters,
                    ),
                ],
              ),
            ),
            if (_isSlowNetwork)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off, size: 16, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(child: Text('Network is slow. Loading may take a little longer.')),
                  ],
                ),
              ),
            if (_isShowingCachedResults)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    Icon(Icons.history, size: 16, color: Colors.blueGrey),
                    SizedBox(width: 8),
                    Expanded(child: Text('Showing cached results while refreshing.')),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null && _listings.isEmpty) {
      return Center(child: Text(_error!));
    }

    if (_isLoading && _listings.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            height: 220,
            child: Align(
              alignment: Alignment.centerLeft,
              child: PropertyCardSkeleton(),
            ),
          ),
        ),
      );
    }

    if (_listings.isEmpty) {
      return const Center(child: Text('No results found. Try widening your filters.'));
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: _listings.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _listings.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final item = _listings[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              child: PropertyCard(
                propertyId: item.id,
                imageUrl: item.imageUrls.isNotEmpty ? item.imageUrls.first : '',
                price: '₹${item.price}',
                title: item.title,
                location: item.city,
                bhk: '${item.bhk} BHK',
                verified: item.verified,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PropertyDetailsScreen(
                        propertyId: item.id,
                        imageUrl: item.imageUrls.isNotEmpty ? item.imageUrls.first : '',
                        price: '₹${item.price}',
                        title: item.title,
                        location: item.city,
                        bhk: '${item.bhk} BHK',
                        brokerId: item.brokerId,
                        imageUrls: item.imageUrls,
                        verified: item.verified,
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickBhk(BuildContext context) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            for (final value in [1, 2, 3, 4, 5])
              ListTile(
                title: Text('$value BHK'),
                trailing: _selectedBhk == value ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, value),
              ),
            ListTile(
              title: const Text('Clear BHK filter'),
              onTap: () => Navigator.pop(context, -1),
            ),
          ],
        ),
      ),
    );

    if (selected == null) return;
    setState(() => _selectedBhk = selected == -1 ? null : selected);
    _onFilterChanged();
  }

  Future<void> _pickPriceRange(BuildContext context) async {
    RangeValues tempRange = _priceRange;
    bool enabled = _priceFilterEnabled;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: enabled,
                    title: const Text('Enable price filter'),
                    onChanged: (value) => setSheetState(() => enabled = value),
                  ),
                  Text(
                    '₹${(tempRange.start / 100000).round()}L - ₹${(tempRange.end / 100000).round()}L',
                  ),
                  RangeSlider(
                    min: 500000,
                    max: 50000000,
                    divisions: 99,
                    values: tempRange,
                    onChanged: enabled
                        ? (value) => setSheetState(() => tempRange = value)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _priceFilterEnabled = false;
                            _priceRange = const RangeValues(1000000, 10000000);
                          });
                          Navigator.pop(context, true);
                        },
                        child: const Text('Clear'),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _priceFilterEnabled = enabled;
                            _priceRange = tempRange;
                          });
                          Navigator.pop(context, true);
                        },
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (applied == true) {
      _onFilterChanged();
    }
  }
}
