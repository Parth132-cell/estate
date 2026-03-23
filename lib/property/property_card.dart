import 'package:estatex_app/favorites/favorite_button.dart';
import 'package:estatex_app/services/saved_service.dart';
import 'package:flutter/material.dart';

class PropertyCard extends StatelessWidget {
  final String propertyId;
  final String imageUrl;
  final String price;
  final String title;
  final String location;
  final String bhk;
  final bool verified;
  final VoidCallback onTap;

  const PropertyCard({
    super.key,
    required this.propertyId,
    required this.imageUrl,
    required this.price,
    required this.title,
    required this.location,
    required this.bhk,
    required this.onTap,
    this.verified = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 🖼 Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Stack(
                children: [
                  imageUrl.isEmpty
                      ? Container(
                          height: 140,
                          width: double.infinity,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.home_work_outlined, size: 48, color: Colors.grey),
                        )
                      : Image.network(
                          imageUrl,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return Container(
                        height: 150,
                        color: Colors.grey.shade300,
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 150,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),

                  /// ❤️ Favorite Button
                  Positioned(
                    top: 6,
                    left: 6,
                    child: _FavoriteIcon(propertyId: propertyId),
                  ),

                  /// 🔄 Compare Button
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: _CompareIcon(propertyId: propertyId),
                  ),

                  /// ✅ Verified badge
                  if (verified)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Verified',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            /// 📄 Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// 💰 Price
                  Text(
                    price,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  /// 🏠 Title
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 4),

                  /// 📍 Location + BHK
                  Text(
                    '$bhk • $location',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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

class _FavoriteIcon extends StatelessWidget {
  final String propertyId;

  const _FavoriteIcon({required this.propertyId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: FavoriteButton(propertyId: propertyId),
      ),
    );
  }
}

class _CompareIcon extends StatelessWidget {
  final String propertyId;

  const _CompareIcon({required this.propertyId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: StreamBuilder<bool>(
          stream: SavedService().isInComparison(propertyId),
          builder: (context, snapshot) {
            final selected = snapshot.data ?? false;

            return IconButton(
              icon: Icon(
                Icons.compare_arrows,
                color: selected ? Colors.blue : Colors.grey,
              ),
              onPressed: () async {
                try {
                  final result = await SavedService().toggleComparison(propertyId);
                  if (!context.mounted) return;
                  if (result == ComparisonToggleResult.limitReached) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('You can compare up to 3 properties at once.'),
                      ),
                    );
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Unable to update comparison: $e')),
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }
}
