import 'package:flutter/material.dart';
import 'review_service.dart';

class AddReviewScreen extends StatefulWidget {
  final String dealId;
  final String propertyId;
  final String brokerId;
  final String reviewerId;

  const AddReviewScreen({
    super.key,
    required this.dealId,
    required this.propertyId,
    required this.brokerId,
    required this.reviewerId,
  });

  @override
  State<AddReviewScreen> createState() => _AddReviewScreenState();
}

class _AddReviewScreenState extends State<AddReviewScreen> {
  int rating = 5;
  final commentCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Leave a Review")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<int>(
              value: rating,
              items: List.generate(
                5,
                (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text("${i + 1} Stars"),
                ),
              ),
              onChanged: (v) => setState(() => rating = v!),
              decoration: const InputDecoration(labelText: "Rating"),
            ),
            TextField(
              controller: commentCtrl,
              decoration: const InputDecoration(labelText: "Comment"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text("Submit Review"),
              onPressed: () async {
                await ReviewService().addReview(
                  dealId: widget.dealId,
                  propertyId: widget.propertyId,
                  brokerId: widget.brokerId,
                  reviewerId: widget.reviewerId,
                  rating: rating,
                  comment: commentCtrl.text,
                );
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
