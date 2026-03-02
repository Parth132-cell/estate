import 'package:flutter/material.dart';

class VerificationCard extends StatelessWidget {
  final String status; // unverified | pending | verified
  final VoidCallback onVerify;

  const VerificationCard({
    super.key,
    required this.status,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    late Color color;
    late String text;

    switch (status) {
      case 'verified':
        color = Colors.green;
        text = 'Verified account';
        break;
      case 'pending':
        color = Colors.orange;
        text = 'Verification in progress';
        break;
      default:
        color = Colors.red;
        text = 'Get verified to unlock features';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.verified, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontWeight: FontWeight.w600, color: color),
            ),
          ),
          if (status == 'unverified')
            ElevatedButton(onPressed: onVerify, child: const Text('Verify')),
        ],
      ),
    );
  }
}
