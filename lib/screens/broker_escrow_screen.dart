import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/colors.dart';
import 'package:estatex_app/payments/escrow_model.dart';
import 'package:estatex_app/payments/escrow_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BrokerEscrowScreen extends StatefulWidget {
  const BrokerEscrowScreen({super.key});

  @override
  State<BrokerEscrowScreen> createState() => _BrokerEscrowScreenState();
}

class _BrokerEscrowScreenState extends State<BrokerEscrowScreen> {
  bool _reconciling = false;

  Future<void> _reconcile() async {
    setState(() => _reconciling = true);
    try {
      final updated = await EscrowService().reconcilePendingEscrows();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reconciled $updated record(s)'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reconcile failed: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _reconciling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Escrow Management'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Reconcile payments',
            onPressed: _reconciling ? null : _reconcile,
            icon: _reconciling
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: EscrowService().brokerEscrow(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Unable to load escrow: ${snapshot.error}'),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = [...(snapshot.data?.docs ?? <QueryDocumentSnapshot>[])]
            ..sort((a, b) {
              final aAt = (a.data() as Map)['createdAt'] as Timestamp?;
              final bAt = (b.data() as Map)['createdAt'] as Timestamp?;
              return (bAt?.millisecondsSinceEpoch ?? 0).compareTo(
                aAt?.millisecondsSinceEpoch ?? 0,
              );
            });

          if (docs.isEmpty) {
            return _EmptyEscrow();
          }

          // Summary header
          final total = docs.fold<int>(
            0,
            (sum, d) =>
                sum + (((d.data() as Map)['amount'] as num?)?.toInt() ?? 0),
          );
          final held = docs
              .where(
                (d) => (d.data() as Map)['status'] == EscrowState.initiated,
              )
              .fold<int>(
                0,
                (sum, d) =>
                    sum + (((d.data() as Map)['amount'] as num?)?.toInt() ?? 0),
              );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary card
              _SummaryCard(
                totalEscrow: total,
                heldAmount: held,
                recordCount: docs.length,
              ),
              const SizedBox(height: 16),

              // Records
              ...docs.map(
                (doc) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _EscrowCard(doc: doc),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────
// SUMMARY CARD
// ─────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final int totalEscrow;
  final int heldAmount;
  final int recordCount;

  const _SummaryCard({
    required this.totalEscrow,
    required this.heldAmount,
    required this.recordCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              label: 'Total Volume',
              value: _fmt(totalEscrow),
              icon: Icons.account_balance_wallet_outlined,
            ),
          ),
          Container(width: 1, height: 48, color: Colors.white24),
          Expanded(
            child: _StatItem(
              label: 'In Escrow',
              value: _fmt(heldAmount),
              icon: Icons.lock_outline,
            ),
          ),
          Container(width: 1, height: 48, color: Colors.white24),
          Expanded(
            child: _StatItem(
              label: 'Records',
              value: '$recordCount',
              icon: Icons.receipt_long_outlined,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(int v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    return '₹${NumberFormat('#,##,###').format(v)}';
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// ESCROW CARD
// ─────────────────────────────────────────

class _EscrowCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  const _EscrowCard({required this.doc});

  @override
  State<_EscrowCard> createState() => _EscrowCardState();
}

class _EscrowCardState extends State<_EscrowCard> {
  bool _busy = false;

  Map<String, dynamic> get _data => widget.doc.data() as Map<String, dynamic>;

  String get _status => (_data['status'] ?? EscrowState.initiated).toString();
  int get _amount => (_data['amount'] as num?)?.toInt() ?? 0;
  String get _paymentStatus => (_data['paymentStatus'] ?? 'unknown').toString();
  String get _txnId => (_data['transactionId'] ?? '-').toString();

  DateTime? get _createdAt => (_data['createdAt'] as Timestamp?)?.toDate();

  Future<void> _release() async {
    final ok = await _confirm(
      'Release Funds',
      'Release ₹${_fmt(_amount)} to the seller/broker? This cannot be undone.',
    );
    if (ok != true) return;
    _doAction(() => EscrowService().release(widget.doc.id));
  }

  Future<void> _refund() async {
    final ok = await _confirm(
      'Refund Buyer',
      'Refund ₹${_fmt(_amount)} to the buyer? This cannot be undone.',
    );
    if (ok != true) return;
    _doAction(() => EscrowService().refund(widget.doc.id));
  }

  Future<bool?> _confirm(String title, String body) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _doAction(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escrow updated'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _fmt(int v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    return NumberFormat('#,##,###').format(v);
  }

  @override
  Widget build(BuildContext context) {
    final canAct =
        _status == EscrowState.initiated ||
        _status == EscrowState.paymentPending;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Amount + status
                Row(
                  children: [
                    Text(
                      '₹${_fmt(_amount)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    _EscrowStatusChip(status: _status),
                  ],
                ),
                const SizedBox(height: 8),

                // Payment status + txn
                _InfoRow(
                  icon: Icons.payment_outlined,
                  label: 'Payment',
                  value: _paymentStatus,
                ),
                if (_txnId != '-')
                  _InfoRow(
                    icon: Icons.tag,
                    label: 'Txn ID',
                    value: _txnId,
                    monospace: true,
                  ),
                if (_createdAt != null)
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Created',
                    value: DateFormat('d MMM y, h:mm a').format(_createdAt!),
                  ),

                // Actions
                if (canAct) ...[
                  const SizedBox(height: 12),
                  _busy
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                ),
                                onPressed: _release,
                                icon: const Icon(Icons.arrow_upward, size: 16),
                                label: const Text('Release'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.orange.shade700,
                                  side: BorderSide(
                                    color: Colors.orange.shade300,
                                  ),
                                ),
                                onPressed: _refund,
                                icon: const Icon(
                                  Icons.arrow_downward,
                                  size: 16,
                                ),
                                label: const Text('Refund'),
                              ),
                            ),
                          ],
                        ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool monospace;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
                fontFamily: monospace ? 'monospace' : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _EscrowStatusChip extends StatelessWidget {
  final String status;
  const _EscrowStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      EscrowState.completed => (
        Colors.green.shade50,
        Colors.green.shade700,
        'Released',
      ),
      EscrowState.cancelled => (
        Colors.red.shade50,
        Colors.red.shade700,
        'Refunded',
      ),
      EscrowState.paymentPending => (
        Colors.amber.shade50,
        Colors.amber.shade700,
        'Pending Payment',
      ),
      _ => (AppColors.primarySoft, AppColors.primary, 'In Escrow'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class _EmptyEscrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              'No escrow records',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'When buyers pay token amounts they will appear here for you to manage.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
