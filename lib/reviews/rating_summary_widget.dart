import 'package:estatex_app/reviews/review_model.dart';
import 'package:flutter/material.dart';
import 'review_service.dart';

class RatingSummaryWidget extends StatelessWidget {
  final String brokerId;

  const RatingSummaryWidget({super.key, required this.brokerId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Review>>(
      stream: ReviewService().forBroker(brokerId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final reviews = snapshot.data!;
        if (reviews.isEmpty) return const Text("No ratings yet");

        final avg =
            reviews.map((r) => r.rating).reduce((a, b) => a + b) /
            reviews.length;

        return Row(
          children: [
            const Icon(Icons.star, color: Colors.amber),
            Text("${avg.toStringAsFixed(1)} (${reviews.length})"),
          ],
        );
      },
    );
  }
}
