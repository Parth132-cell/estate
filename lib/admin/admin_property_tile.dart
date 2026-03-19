import 'package:flutter/material.dart';

import '../services/admin_services.dart';

class AdminPropertyTile extends StatelessWidget {
  final String propertyId;
  final String title;
  final String city;
  final int price;
  final String status;
  final String? rejectionReason;
  final VoidCallback? onModerated;

  const AdminPropertyTile({
    super.key,
    required this.propertyId,
    required this.title,
    required this.city,
    required this.price,
    required this.status,
    this.rejectionReason,
    this.onModerated,
  });

  @override
  Widget build(BuildContext context) {
    final adminService = AdminService();
    final canModerate = status == 'pending';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('₹$price • $city'),
                    ],
                  ),
                ),
                _StatusChip(status: status),
              ],
            ),
            if ((rejectionReason ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Reason: ${rejectionReason!.trim()}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
            const SizedBox(height: 12),
            if (canModerate)
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      await adminService.approveProperty(propertyId);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Property approved')),
                      );
                      onModerated?.call();
                    },
                    child: const Text('Approve'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () async {
                      final reason = await _showRejectReasonDialog(context);
                      if (reason == null || reason.trim().isEmpty) return;

                      await adminService.rejectProperty(
                        propertyId: propertyId,
                        reason: reason,
                      );

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Property rejected')),
                      );
                      onModerated?.call();
                    },
                    child: const Text('Reject'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showRejectReasonDialog(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reject property'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Add rejection reason',
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Reason is required';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(dialogContext, controller.text.trim());
              },
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final (Color color, String label) = switch (normalized) {
      'approved' => (Colors.green, 'Approved'),
      'rejected' => (Colors.redAccent, 'Rejected'),
      _ => (Colors.orange, 'Pending'),
    };

    return Chip(
      label: Text(label),
      labelStyle: const TextStyle(color: Colors.white),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
    );
  }
}
