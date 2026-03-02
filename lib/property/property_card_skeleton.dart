import 'package:flutter/material.dart';
import '../../ui/shimmer/shimmer_box.dart';

class PropertyCardSkeleton extends StatelessWidget {
  const PropertyCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          const ShimmerBox(
            width: double.infinity,
            height: 140,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(16),
              bottom: Radius.circular(16),
            ),
          ),
          const SizedBox(height: 12),

          // Price
          const ShimmerBox(width: 120, height: 20),
          const SizedBox(height: 8),

          // Title
          const ShimmerBox(width: 180, height: 14),
          const SizedBox(height: 6),

          // Location
          const ShimmerBox(width: 140, height: 12),
        ],
      ),
    );
  }
}
