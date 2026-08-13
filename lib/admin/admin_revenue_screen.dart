import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminRevenueScreen extends StatelessWidget {
  const AdminRevenueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Revenue Dashboard'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('platform_fees')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];

          final totalCollected = docs
              .where((d) => d.data()['status'] == 'collected')
              .fold<int>(
                0,
                (sum, d) => sum + ((d.data()['amount'] as num?)?.toInt() ?? 0),
              );

          final totalPending = docs
              .where((d) => d.data()['status'] == 'pending')
              .fold<int>(
                0,
                (sum, d) => sum + ((d.data()['amount'] as num?)?.toInt() ?? 0),
              );

          final totalDeals = docs.length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Summary cards ──
              Row(
                children: [
                  Expanded(
                    child: _RevenueCard(
                      label: 'Collected',
                      amount: totalCollected,
                      icon: Icons.account_balance_wallet_outlined,
                      color: Colors.green.shade700,
                      bg: Colors.green.shade50,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RevenueCard(
                      label: 'Pending',
                      amount: totalPending,
                      icon: Icons.hourglass_top_outlined,
                      color: Colors.orange.shade700,
                      bg: Colors.orange.shade50,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Revenue model explanation ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Revenue streams',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _RevenueStream(
                      icon: Icons.percent,
                      title: 'Transaction fee',
                      subtitle: '1.5% of deal value on escrow release',
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 10),
                    _RevenueStream(
                      icon: Icons.workspace_premium_outlined,
                      title: 'Broker subscription',
                      subtitle: '₹499–999/month for CRM + verified badge',
                      color: const Color(0xFF7C3AED),
                    ),
                    const SizedBox(height: 10),
                    _RevenueStream(
                      icon: Icons.rocket_launch_outlined,
                      title: 'Featured listing boost',
                      subtitle: '₹999–2,999 per listing per month',
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(height: 10),
                    _RevenueStream(
                      icon: Icons.group_outlined,
                      title: 'Lead generation',
                      subtitle: 'Pay-per-qualified-lead for brokers',
                      color: Colors.green.shade700,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Fee records ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Fee records',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$totalDeals total',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (docs.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No fees recorded yet.\nFees are recorded when buyers pay token amounts.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                ...docs.take(50).map((doc) {
                  final data = doc.data();
                  final amount = (data['amount'] as num?)?.toInt() ?? 0;
                  final status = (data['status'] ?? 'pending').toString();
                  final dealValue = (data['dealValue'] as num?)?.toInt() ?? 0;
                  final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                  final dealId = data['dealId']?.toString() ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: status == 'collected'
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            status == 'collected'
                                ? Icons.check_circle_outline
                                : Icons.hourglass_top_outlined,
                            color: status == 'collected'
                                ? Colors.green.shade600
                                : Colors.orange.shade600,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Deal #${dealId.length >= 8 ? dealId.substring(0, 8).toUpperCase() : dealId}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'Deal value: ${_fmtAmount(dealValue)} · 1.5% fee',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (createdAt != null)
                                Text(
                                  DateFormat('d MMM y').format(createdAt),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _fmtAmount(amount),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: status == 'collected'
                                    ? Colors.green.shade50
                                    : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                status == 'collected' ? 'Collected' : 'Pending',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: status == 'collected'
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }

  String _fmtAmount(int v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    return '₹${NumberFormat('#,##,###').format(v)}';
  }
}

class _RevenueCard extends StatelessWidget {
  final String label;
  final int amount;
  final IconData icon;
  final Color color;
  final Color bg;

  const _RevenueCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
    required this.bg,
  });

  String _fmt(int v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(0)}K';
    return '₹$v';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            _fmt(amount),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueStream extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _RevenueStream({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
