import 'package:estatex_app/explore/property_listing_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ExploreMapView extends StatelessWidget {
  const ExploreMapView({
    super.key,
    required this.listings,
    required this.onOpenListing,
  });

  final List<PropertyListing> listings;
  final ValueChanged<PropertyListing> onOpenListing;

  @override
  Widget build(BuildContext context) {
    if (listings.isEmpty) {
      return const Center(
        child: Text('No map results for the current filters'),
      );
    }

    final center = _centerForListings(listings);

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 11,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.estatex.app',
            ),
            MarkerLayer(
              markers: listings
                  .map(
                    (item) => Marker(
                      point: LatLng(item.latitude, item.longitude),
                      width: 90,
                      height: 42,
                      child: GestureDetector(
                        onTap: () => onOpenListing(item),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x22000000),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                            border: Border.all(color: const Color(0xFF1D4ED8)),
                          ),
                          child: Text(
                            _priceLabel(item.price),
                            style: const TextStyle(
                              color: Color(0xFF1D4ED8),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: SizedBox(
            height: 124,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: listings.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = listings[index];
                return GestureDetector(
                  onTap: () => onOpenListing(item),
                  child: Container(
                    width: 260,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _priceLabel(item.price),
                          style: const TextStyle(
                            color: Color(0xFF1D4ED8),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.locationLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const Spacer(),
                        Text(
                          '${item.bhk} BHK',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  static LatLng _centerForListings(List<PropertyListing> items) {
    final lat =
        items.fold<double>(0, (sum, item) => sum + item.latitude) / items.length;
    final lng =
        items.fold<double>(0, (sum, item) => sum + item.longitude) / items.length;
    return LatLng(lat, lng);
  }

  static String _priceLabel(int price) {
    if (price >= 10000000) {
      return 'INR ${(price / 10000000).toStringAsFixed(1)} Cr';
    }
    if (price >= 100000) {
      return 'INR ${(price / 100000).toStringAsFixed(0)} L';
    }
    return 'INR $price';
  }
}
