import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/colors.dart';
import 'package:estatex_app/contact/contact_chat_screen.dart';

import 'package:estatex_app/reviews/rating_summary_widget.dart';
import 'package:estatex_app/screens/visit_schedule_screen.dart';
import 'package:estatex_app/services/deal_services.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class PropertyDetailsScreen extends StatefulWidget {
  final String propertyId;
  final String imageUrl;
  final List<String> imageUrls;
  final String price;
  final String title;
  final String location;
  final String bhk;
  final String brokerId;
  final bool verified;

  const PropertyDetailsScreen({
    super.key,
    required this.propertyId,
    required this.imageUrl,
    required this.imageUrls,
    required this.price,
    required this.title,
    required this.location,
    required this.bhk,
    required this.brokerId,
    required this.verified,
  });

  @override
  State<PropertyDetailsScreen> createState() => _PropertyDetailsScreenState();
}

class _PropertyDetailsScreenState extends State<PropertyDetailsScreen> {
  final _pageCtrl = PageController();
  int _currentImage = 0;
  bool _isFavorited = false;
  bool _loadingFav = false;

  @override
  void initState() {
    super.initState();
    _checkFavorite();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkFavorite() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('favorites')
          .doc(widget.propertyId)
          .get();
      if (mounted) setState(() => _isFavorited = doc.exists);
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _loadingFav = true);
    try {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('favorites')
          .doc(widget.propertyId);
      if (_isFavorited) {
        await ref.delete();
      } else {
        await ref.set({
          'propertyId': widget.propertyId,
          'savedAt': FieldValue.serverTimestamp(),
        });
      }
      if (mounted) setState(() => _isFavorited = !_isFavorited);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingFav = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: _CircleBtn(
            icon: Icons.arrow_back,
            onTap: () => Navigator.pop(context),
          ),
        ),
        actions: [
          _CircleBtn(
            icon: _isFavorited ? Icons.favorite : Icons.favorite_border,
            color: _isFavorited ? Colors.red : null,
            onTap: _loadingFav ? null : _toggleFavorite,
          ),
          _CircleBtn(icon: Icons.share_outlined, onTap: () {}),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('properties')
            .doc(widget.propertyId)
            .snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data() ?? {};
          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _GallerySection(
                      images: widget.imageUrls.isNotEmpty
                          ? widget.imageUrls
                          : [widget.imageUrl],
                      controller: _pageCtrl,
                      currentIndex: _currentImage,
                      onPageChanged: (i) => setState(() => _currentImage = i),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PriceHeader(
                            price: widget.price,
                            verified: widget.verified,
                            data: data,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            data['title']?.toString() ?? widget.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _location(data),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _SpecsGrid(data: data, bhk: widget.bhk),
                          const SizedBox(height: 20),
                          _divider(),
                          if ((data['description'] ?? '')
                              .toString()
                              .isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _Description(text: data['description'].toString()),
                            const SizedBox(height: 20),
                            _divider(),
                          ],
                          if (_amenities(data).isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _Amenities(items: _amenities(data)),
                            const SizedBox(height: 20),
                            _divider(),
                          ],
                          const SizedBox(height: 16),
                          _PriceDetails(price: widget.price, data: data),
                          const SizedBox(height: 20),
                          _divider(),
                          if (widget.brokerId.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _AgentCard(brokerId: widget.brokerId),
                            const SizedBox(height: 20),
                            _divider(),
                          ],
                          const SizedBox(height: 16),
                          _LocationSection(data: data),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _CtaBar(
                  propertyId: widget.propertyId,
                  brokerId: widget.brokerId,
                  title: data['title']?.toString() ?? widget.title,
                  price: widget.price,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _divider() => Divider(height: 1, color: Colors.grey.shade100);

  String _location(Map<String, dynamic> d) {
    final parts = <String>[];
    final loc = d['locality']?.toString() ?? '';
    final city = d['city']?.toString() ?? widget.location;
    if (loc.isNotEmpty) parts.add(loc);
    if (city.isNotEmpty) parts.add(city);
    return parts.isNotEmpty ? parts.join(', ') : widget.location;
  }

  List<String> _amenities(Map<String, dynamic> d) {
    final raw = d['amenities'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return [];
  }
}

// ── Gallery ──────────────────────────────

class _GallerySection extends StatelessWidget {
  final List<String> images;
  final PageController controller;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;

  const _GallerySection({
    required this.images,
    required this.controller,
    required this.currentIndex,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          PageView.builder(
            controller: controller,
            onPageChanged: onPageChanged,
            itemCount: images.length,
            itemBuilder: (_, i) => Image.network(
              images[i],
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade200,
                child: const Icon(
                  Icons.image_outlined,
                  size: 48,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          // Top gradient for AppBar contrast
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 80,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.45), Colors.transparent],
                ),
              ),
            ),
          ),
          // Counter
          if (images.length > 1)
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${currentIndex + 1} / ${images.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          // Dots
          if (images.length > 1 && images.length <= 8)
            Positioned(
              bottom: 14,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == currentIndex ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == currentIndex
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Price header ─────────────────────────

class _PriceHeader extends StatelessWidget {
  final String price;
  final bool verified;
  final Map<String, dynamic> data;

  const _PriceHeader({
    required this.price,
    required this.verified,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final cat = (data['propertyCategory'] ?? 'apartment').toString();
    final listing = (data['listingType'] ?? 'sale').toString();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _fmtPrice(price),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              if (data['pricePerSqft'] != null)
                Text(
                  '₹${data['pricePerSqft']}/sq.ft',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (verified)
              _chip(
                'Verified',
                Icons.verified_outlined,
                Colors.green.shade700,
                Colors.green.shade50,
              ),
            const SizedBox(height: 4),
            _chip(
              _listingLabel(listing),
              Icons.sell_outlined,
              AppColors.primary,
              AppColors.primarySoft,
            ),
            const SizedBox(height: 4),
            _chip(
              _catLabel(cat),
              _catIcon(cat),
              Colors.grey.shade600,
              Colors.grey.shade100,
            ),
          ],
        ),
      ],
    );
  }

  Widget _chip(String l, IconData ic, Color c, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ic, size: 12, color: c),
          const SizedBox(width: 4),
          Text(
            l,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtPrice(String raw) {
    final n = int.tryParse(raw.replaceAll(RegExp(r'[^\d]'), ''));
    if (n == null) return raw;
    if (n >= 10000000) return '₹${(n / 10000000).toStringAsFixed(2)} Cr';
    if (n >= 100000) return '₹${(n / 100000).toStringAsFixed(1)} L';
    return '₹${NumberFormat('#,##,###').format(n)}';
  }

  String _listingLabel(String t) => t == 'rent'
      ? 'For Rent'
      : t == 'lease'
      ? 'For Lease'
      : 'For Sale';

  String _catLabel(String c) {
    const m = {
      'house': 'House',
      'villa': 'Villa',
      'plot': 'Plot',
      'land': 'Land',
      'commercial': 'Commercial',
      'warehouse': 'Warehouse',
    };
    return m[c] ?? 'Apartment';
  }

  IconData _catIcon(String c) {
    if (c == 'plot' || c == 'land') return Icons.landscape_outlined;
    if (c == 'commercial' || c == 'warehouse') return Icons.store_outlined;
    if (c == 'villa') return Icons.villa_outlined;
    if (c == 'house') return Icons.home_outlined;
    return Icons.apartment_outlined;
  }
}

// ── Specs grid ───────────────────────────

class _SpecsGrid extends StatelessWidget {
  final Map<String, dynamic> data;
  final String bhk;

  const _SpecsGrid({required this.data, required this.bhk});

  @override
  Widget build(BuildContext context) {
    final cat = (data['propertyCategory'] ?? 'apartment').toString();
    final isRes = const {'apartment', 'house', 'villa'}.contains(cat);
    final area = data['areaSqft'] ?? data['area'];
    final unit = (cat == 'plot' || cat == 'land') ? 'sq.yd' : 'sq.ft';

    final specs = <_Spec>[];
    if (isRes && bhk.isNotEmpty && bhk != '0 BHK') {
      specs.add(_Spec(Icons.bed_outlined, bhk));
    }
    if (area != null)
      specs.add(_Spec(Icons.straighten_outlined, '$area $unit'));
    if (data['floor'] != null && isRes) {
      final f = data['floor'];
      final tf = data['totalFloors'];
      specs.add(
        _Spec(Icons.layers_outlined, tf != null ? 'Floor $f/$tf' : 'Floor $f'),
      );
    }
    if (data['facing'] != null)
      specs.add(_Spec(Icons.explore_outlined, '${data['facing']} facing'));
    if (data['parking'] == true)
      specs.add(const _Spec(Icons.local_parking_outlined, 'Parking'));
    if (data['propertyAge'] != null)
      specs.add(
        _Spec(Icons.history_outlined, '${data['propertyAge']} yrs old'),
      );

    if (specs.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        spacing: 0,
        runSpacing: 0,
        children: specs.map((s) {
          return SizedBox(
            width: (MediaQuery.of(context).size.width - 60) / 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Column(
                children: [
                  Icon(s.icon, size: 22, color: AppColors.primary),
                  const SizedBox(height: 4),
                  Text(
                    s.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Spec {
  final IconData icon;
  final String label;
  const _Spec(this.icon, this.label);
}

// ── Description ──────────────────────────

class _Description extends StatefulWidget {
  final String text;
  const _Description({required this.text});

  @override
  State<_Description> createState() => _DescriptionState();
}

class _DescriptionState extends State<_Description> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About this property',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: Text(
            widget.text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          secondChild: Text(
            widget.text,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ),
        if (widget.text.length > 150) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? 'Show less' : 'Read more',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Amenities ────────────────────────────

class _Amenities extends StatelessWidget {
  final List<String> items;
  const _Amenities({required this.items});

  static const _icons = <String, IconData>{
    'gym': Icons.fitness_center_outlined,
    'swimming pool': Icons.pool_outlined,
    'lift': Icons.elevator_outlined,
    'security': Icons.security_outlined,
    'power backup': Icons.power_outlined,
    'garden': Icons.park_outlined,
    'clubhouse': Icons.meeting_room_outlined,
    'cctv': Icons.videocam_outlined,
    'parking': Icons.local_parking_outlined,
    'wifi': Icons.wifi_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Amenities',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items.map((a) {
            final ic = _icons[a.toLowerCase()] ?? Icons.check_circle_outline;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(ic, size: 15, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    a,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Price details (shows platform fee) ───

class _PriceDetails extends StatelessWidget {
  final String price;
  final Map<String, dynamic> data;

  const _PriceDetails({required this.price, required this.data});

  @override
  Widget build(BuildContext context) {
    final raw = int.tryParse(price.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    final area = (data['areaSqft'] as num?)?.toInt();
    final perSqft = area != null && area > 0 ? (raw / area).round() : null;
    final fee = (raw * 0.015).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Price details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            children: [
              _row('Base price', _fmt(raw)),
              if (perSqft != null) _row('Price per sq.ft', '₹${_n(perSqft)}'),
              const Divider(height: 1),
              _row(
                'EstateX fee (1.5%)',
                '₹${_n(fee)}',
                sub: 'on deal close · no upfront charge',
                muted: true,
              ),
              const Divider(height: 1),
              _row('Total payable', _fmt(raw + fee), bold: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(
    String l,
    String v, {
    String? sub,
    bool muted = false,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l,
                  style: TextStyle(
                    fontSize: 14,
                    color: muted ? Colors.grey.shade500 : AppColors.textPrimary,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (sub != null)
                  Text(
                    sub,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  ),
              ],
            ),
          ),
          Text(
            v,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: bold
                  ? AppColors.primary
                  : (muted ? Colors.grey.shade500 : AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(int v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)} Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)} L';
    return '₹${NumberFormat('#,##,###').format(v)}';
  }

  String _n(int v) => NumberFormat('#,##,###').format(v);
}

// ── Agent card (NO phone number) ─────────

class _AgentCard extends StatelessWidget {
  final String brokerId;
  const _AgentCard({required this.brokerId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(brokerId)
          .get(),
      builder: (context, snap) {
        final d = snap.data?.data() ?? {};
        final name = (d['name'] ?? 'Agent').toString();
        final role = (d['role'] ?? 'seller').toString();
        final avg = (d['avgRating'] as num?)?.toDouble() ?? 0.0;
        final cnt = (d['reviewCount'] as num?)?.toInt() ?? 0;
        final verified = d['brokerApprovalStatus'] == 'approved';
        final rera = d['reraNumber']?.toString() ?? '';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Listed by',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade100),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primarySoft,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (verified) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified,
                                color: Colors.blue,
                                size: 16,
                              ),
                            ],
                          ],
                        ),
                        Text(
                          role == 'broker'
                              ? 'Verified Broker'
                              : 'Property Owner',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (avg > 0) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Colors.amber,
                                size: 14,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${avg.toStringAsFixed(1)} ($cnt reviews)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (rera.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'RERA: $rera',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: const [
                  Icon(Icons.shield_outlined, size: 14, color: Colors.amber),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'For privacy, contact is done through EstateX chat only — no phone number is shared.',
                      style: TextStyle(fontSize: 11, color: Colors.amber),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Location section ─────────────────────

class _LocationSection extends StatelessWidget {
  final Map<String, dynamic> data;
  const _LocationSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final lat = (data['latitude'] as num?)?.toDouble();
    final lng = (data['longitude'] as num?)?.toDouble();
    final loc = [
      data['locality']?.toString() ?? '',
      data['city']?.toString() ?? '',
    ].where((s) => s.isNotEmpty).join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Location',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: lat != null
              ? () async {
                  final url = Uri.parse('https://maps.google.com/?q=$lat,$lng');
                  if (await canLaunchUrl(url)) launchUrl(url);
                }
              : null,
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 36,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                  if (loc.isNotEmpty)
                    Text(
                      loc,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  const SizedBox(height: 4),
                  if (lat != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.open_in_new,
                          size: 13,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Open in Google Maps',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── CTA bar ──────────────────────────────

class _CtaBar extends StatefulWidget {
  final String propertyId;
  final String brokerId;
  final String title;
  final String price;

  const _CtaBar({
    required this.propertyId,
    required this.brokerId,
    required this.title,
    required this.price,
  });

  @override
  State<_CtaBar> createState() => _CtaBarState();
}

class _CtaBarState extends State<_CtaBar> {
  bool _submitting = false;

  Future<void> _makeOffer() async {
    final raw =
        int.tryParse(widget.price.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    final ctrl = TextEditingController(text: raw.toString());
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Make an offer',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Your offer (₹)',
                prefixIcon: const Icon(Icons.currency_rupee),
                helperText: 'Listed price: ${widget.price}',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: AppButtons.primary,
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Submit Offer',
                  style: TextStyle(fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _submitting = true);
    try {
      final amt = int.tryParse(ctrl.text.trim()) ?? 0;
      await DealServices().createOffer(
        propertyId: widget.propertyId,
        sellerId: widget.brokerId,
        amount: amt,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Offer submitted!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Chat — no number exposed
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ContactChatScreen(
                    brokerId: widget.brokerId,
                    propertyId: widget.propertyId,
                    propertyTitle: widget.title,
                  ),
                ),
              ),
              icon: const Icon(Icons.chat_outlined, size: 18),
              label: const Text('Chat'),
            ),
          ),
          const SizedBox(width: 8),
          // Visit
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VisitScheduleScreen(
                    initialPropertyId: widget.propertyId,
                    initialBrokerId: widget.brokerId,
                  ),
                ),
              ),
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: const Text('Visit'),
            ),
          ),
          const SizedBox(width: 8),
          // Offer
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              style: AppButtons.primary,
              onPressed: _submitting ? null : _makeOffer,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.local_offer_outlined, size: 18),
              label: Text(
                _submitting ? 'Submitting…' : 'Make Offer',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ──────────────────────────────

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  const _CircleBtn({required this.icon, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: color ?? Colors.white),
      ),
    );
  }
}
