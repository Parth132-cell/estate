import 'package:estatex_app/colors.dart';
import 'package:estatex_app/property/add_property/property_type_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PROPERTY CARD
// Used in HomeScreen (horizontal scroll), ExploreScreen (list),
// AI picks, saved properties, compare screen.
// ─────────────────────────────────────────────────────────────────────────────

class PropertyCard extends StatelessWidget {
  final String propertyId;
  final String imageUrl;
  final String price;
  final String title;
  final String location;
  final String bhk;
  final bool verified;
  final VoidCallback onTap;

  // Optional rich data — used when available to show more detail
  final int? rawPrice;
  final int? areaSqft;
  final String? propertyCategory;
  final bool? isFeatured;
  final String? listingType;
  final String? locality;

  const PropertyCard({
    super.key,
    required this.propertyId,
    required this.imageUrl,
    required this.price,
    required this.title,
    required this.location,
    required this.bhk,
    required this.verified,
    required this.onTap,
    this.rawPrice,
    this.areaSqft,
    this.propertyCategory,
    this.isFeatured,
    this.listingType,
    this.locality,
  });

  // ── Horizontal card (for home screen carousels) ──────────────────────────
  static PropertyCard horizontal({
    required String propertyId,
    required String imageUrl,
    required String price,
    required String title,
    required String location,
    required String bhk,
    required bool verified,
    required VoidCallback onTap,
    int? rawPrice,
    int? areaSqft,
    String? propertyCategory,
    bool? isFeatured,
    String? listingType,
    String? locality,
  }) {
    return PropertyCard(
      propertyId: propertyId,
      imageUrl: imageUrl,
      price: price,
      title: title,
      location: location,
      bhk: bhk,
      verified: verified,
      onTap: onTap,
      rawPrice: rawPrice,
      areaSqft: areaSqft,
      propertyCategory: propertyCategory,
      isFeatured: isFeatured,
      listingType: listingType,
      locality: locality,
    );
  }

  String get _formattedPrice {
    if (rawPrice != null && rawPrice! > 0) {
      return _fmt(rawPrice!);
    }
    return price;
  }

  String _fmt(int v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)} Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)} L';
    return '₹${NumberFormat('#,##,###').format(v)}';
  }

  @override
  Widget build(BuildContext context) {
    final cat = PropertyCategory.fromKey(propertyCategory ?? 'apartment');
    final featured = isFeatured ?? false;
    final isOwner = listingType == 'individual';
    final pricePerSqft =
        (rawPrice != null && areaSqft != null && areaSqft! > 0 && rawPrice! > 0)
        ? (rawPrice! / areaSqft!).round()
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 230,
        margin: const EdgeInsets.only(right: 14, bottom: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: featured
              ? Border.all(color: Colors.orange.shade300, width: 1.5)
              : Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image section ──
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          height: 132,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _ImgPlaceholder(height: 132),
                        )
                      : _ImgPlaceholder(height: 132),
                ),

                // Category badge — top left
                Positioned(
                  top: 8,
                  left: 8,
                  child: _CardBadge(label: cat.label, color: cat.group.color),
                ),

                // Featured badge — top right
                if (featured)
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: _CardBadge(label: '⭐', color: Colors.orange),
                  ),

                // Verified tick — bottom left
                if (verified)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_outlined,
                            color: Colors.white,
                            size: 10,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Verified',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Owner / Broker tag — bottom right
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isOwner ? 'Owner' : 'Broker',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── Info section ──
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          _formattedPrice,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (pricePerSqft != null)
                        Text(
                          '₹$pricePerSqft/sf',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  // Title
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),

                  // Location
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          locality != null && locality!.isNotEmpty
                              ? '$locality, $location'
                              : location,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Stats
                  Row(
                    children: [
                      if (bhk.isNotEmpty && bhk != '0 BHK' && cat.hasBhk) ...[
                        _MiniStat(icon: Icons.bed_outlined, label: bhk),
                        const SizedBox(width: 8),
                      ],
                      if (areaSqft != null && areaSqft! > 0)
                        _MiniStat(
                          icon: Icons.square_foot_outlined,
                          label: '$areaSqft sqft',
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
}

// ─────────────────────────────────────────────────────────────────────────────
// PROPERTY CARD — VERTICAL (list view, full width)
// ─────────────────────────────────────────────────────────────────────────────

class PropertyCardVertical extends StatelessWidget {
  final String propertyId;
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const PropertyCardVertical({
    super.key,
    required this.propertyId,
    required this.data,
    required this.onTap,
  });

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
    final verified = data['verificationStatus'] == 'approved';
    final featured = data['isFeatured'] == true;
    final listingType = (data['listingType'] ?? 'individual').toString();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: featured
              ? Border.all(color: Colors.orange.shade300)
              : Border.all(color: Colors.grey.shade100),
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
            // Thumbnail
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                  child: images.isNotEmpty
                      ? Image.network(
                          images.first,
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _ImgPlaceholder(width: 110, height: 110),
                        )
                      : _ImgPlaceholder(width: 110, height: 110),
                ),
                // Category pill on image
                Positioned(
                  bottom: 6,
                  left: 6,
                  child: _CardBadge(
                    label: cat.label,
                    color: cat.group.color,
                    small: true,
                  ),
                ),
              ],
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Price row
                    Row(
                      children: [
                        Text(
                          price > 0 ? _fmt(price) : 'Price on request',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const Spacer(),
                        if (verified)
                          const Icon(
                            Icons.verified,
                            color: Colors.green,
                            size: 16,
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Title
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),

                    // Location
                    Text(
                      locality.isNotEmpty ? '$locality, $city' : city,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Stats + listing type
                    Row(
                      children: [
                        if (bhk > 0 && cat.hasBhk) ...[
                          _MiniStat(
                            icon: Icons.bed_outlined,
                            label: '$bhk BHK',
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (area > 0)
                          _MiniStat(
                            icon: Icons.square_foot_outlined,
                            label: '$area sqft',
                          ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: listingType == 'professional'
                                ? const Color(0xFFF5F3FF)
                                : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            listingType == 'professional' ? 'Broker' : 'Owner',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: listingType == 'professional'
                                  ? const Color(0xFF7C3AED)
                                  : Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SKELETON LOADER
// ─────────────────────────────────────────────────────────────────────────────

class PropertyCardSkeleton extends StatefulWidget {
  final bool horizontal;

  const PropertyCardSkeleton({super.key, this.horizontal = true});

  @override
  State<PropertyCardSkeleton> createState() => _PropertyCardSkeletonState();
}

class _PropertyCardSkeletonState extends State<PropertyCardSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.4,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _box(double w, double h, {double r = 6, Color? color}) =>
      AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: (color ?? Colors.grey.shade200).withOpacity(_anim.value),
            borderRadius: BorderRadius.circular(r),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (widget.horizontal) {
      return Container(
        width: 230,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _box(double.infinity, 140, r: 0),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(100, 16),
                  const SizedBox(height: 6),
                  _box(160, 14),
                  const SizedBox(height: 6),
                  _box(120, 12),
                  const SizedBox(height: 8),
                  _box(80, 11),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Vertical skeleton
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          _box(110, 110, r: 0),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(90, 15),
                  const SizedBox(height: 6),
                  _box(160, 13),
                  const SizedBox(height: 5),
                  _box(120, 11),
                  const SizedBox(height: 8),
                  _box(100, 11),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────

class _CardBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool small;

  const _CardBadge({
    required this.label,
    required this.color,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 5 : 7,
        vertical: small ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: small ? 9 : 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _ImgPlaceholder extends StatelessWidget {
  final double? width;
  final double height;

  const _ImgPlaceholder({this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      color: Colors.grey.shade200,
      child: const Icon(Icons.home_outlined, color: Colors.grey, size: 36),
    );
  }
}
