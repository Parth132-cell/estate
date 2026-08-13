import 'package:flutter/material.dart';

import '../colors.dart';
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
  final _commentController = TextEditingController();
  final _service = ReviewService();

  int _rating = 0; // 0 = not yet selected
  bool _submitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      _snack('Please select a star rating');
      return;
    }
    if (_commentController.text.trim().isEmpty) {
      _snack('Please write a short comment');
      return;
    }

    setState(() => _submitting = true);

    try {
      await _service.addReview(
        dealId: widget.dealId,
        propertyId: widget.propertyId,
        brokerId: widget.brokerId,
        reviewerId: widget.reviewerId,
        rating: _rating,
        comment: _commentController.text.trim(),
      );
      setState(() => _submitted = true);
    } on ReviewAlreadyExistsException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Failed to submit review. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Leave a Review'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _submitted
          ? _SuccessView(onDone: () => Navigator.pop(context))
          : _Form(
              rating: _rating,
              submitting: _submitting,
              commentController: _commentController,
              onRatingSelect: (r) => setState(() => _rating = r),
              onSubmit: _submit,
            ),
    );
  }
}

// ─────────────────────────────────────────
// FORM
// ─────────────────────────────────────────

class _Form extends StatelessWidget {
  final int rating;
  final bool submitting;
  final TextEditingController commentController;
  final ValueChanged<int> onRatingSelect;
  final VoidCallback onSubmit;

  const _Form({
    required this.rating,
    required this.submitting,
    required this.commentController,
    required this.onRatingSelect,
    required this.onSubmit,
  });

  static const _labels = ['', 'Poor', 'Fair', 'Good', 'Very Good', 'Excellent'];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'How was your experience?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your review helps other buyers and builds trust on EstateX.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 32),

          // Star selector
          const Text(
            'Rate your experience',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: () => onRatingSelect(star),
                child: AnimatedScale(
                  scale: rating >= star ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      rating >= star
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 44,
                      color: rating >= star
                          ? Colors.amber.shade600
                          : Colors.grey.shade300,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: rating > 0
                  ? Text(
                      _labels[rating],
                      key: ValueKey(rating),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade700,
                      ),
                    )
                  : const Text(
                      'Tap to rate',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 28),

          // Comment
          const Text(
            'Write a comment',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: commentController,
            maxLines: 5,
            minLines: 3,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText:
                  'Tell others about the property, the broker, and how the deal went…',
              hintMaxLines: 2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),

          const SizedBox(height: 24),

          // Submit
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: AppButtons.primary,
              onPressed: submitting ? null : onSubmit,
              child: submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Submit Review',
                      style: TextStyle(
                        fontSize: 16,
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

// ─────────────────────────────────────────
// SUCCESS VIEW
// ─────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final VoidCallback onDone;
  const _SuccessView({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: 64,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Review submitted!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Thank you for helping the EstateX community make better decisions.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: AppButtons.primary,
              onPressed: onDone,
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
