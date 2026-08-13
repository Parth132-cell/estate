import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/agreements/agreement_screen.dart';
import 'package:estatex_app/colors.dart';
import 'package:estatex_app/payments/escrow_model.dart';
import 'package:estatex_app/payments/escrow_service.dart';
import 'package:estatex_app/services/deal_services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BuyerDealsScreen extends StatelessWidget {
  const BuyerDealsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('My Offers'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: DealServices().buyerDeals(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final deals = [...(snapshot.data?.docs ?? [])]
            ..sort((a, b) {
              final aAt = a.data()['createdAt'] as Timestamp?;
              final bAt = b.data()['createdAt'] as Timestamp?;
              return (bAt?.millisecondsSinceEpoch ?? 0).compareTo(
                aAt?.millisecondsSinceEpoch ?? 0,
              );
            });

          if (deals.isEmpty) return const _EmptyDeals();

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: deals.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = deals[index];
              return _DealCard(dealId: doc.id, deal: doc.data());
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────
// DEAL CARD
// ─────────────────────────────────────────

class _DealCard extends StatefulWidget {
  final String dealId;
  final Map<String, dynamic> deal;

  const _DealCard({required this.dealId, required this.deal});

  @override
  State<_DealCard> createState() => _DealCardState();
}

class _DealCardState extends State<_DealCard> {
  bool _payingToken = false;
  Map<String, dynamic>? _propertyData;
  bool _loadingProperty = true;

  @override
  void initState() {
    super.initState();
    _fetchProperty();
  }

  Future<void> _fetchProperty() async {
    final pid = widget.deal['propertyId']?.toString() ?? '';
    if (pid.isEmpty) {
      setState(() => _loadingProperty = false);
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('properties')
          .doc(pid)
          .get();
      if (mounted) {
        setState(() {
          _propertyData = snap.data();
          _loadingProperty = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProperty = false);
    }
  }

  String get _status => (widget.deal['status'] ?? 'pending').toString();
  int get _amount => (widget.deal['amount'] as num?)?.toInt() ?? 0;
  String get _dealRef => '#${widget.dealId.substring(0, 8).toUpperCase()}';

  Future<void> _payToken() async {
    final tokenAmount = (_amount * 0.1).toInt();
    // EstateX fee: 1.5% of deal value
    final platformFee = (_amount * 0.015).toInt();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Token Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Property snapshot
            if (_propertyData != null) _PropertySnapshot(data: _propertyData!),
            const SizedBox(height: 14),
            _PaymentRow(
              label: 'Token amount (10%)',
              value: _fmt(tokenAmount),
              bold: true,
            ),
            _PaymentRow(
              label: 'EstateX platform fee (1.5%)',
              value: _fmt(platformFee),
              color: AppColors.primary,
            ),
            const Divider(height: 16),
            _PaymentRow(
              label: 'Total payable now',
              value: _fmt(tokenAmount + platformFee),
              bold: true,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline, size: 14, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Token amount is held in EstateX escrow until the deal closes.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: AppButtons.primary,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Pay ${_fmt(tokenAmount + platformFee)}'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _payingToken = true);
    try {
      await EscrowService().createEscrowWithPayment(
        dealId: widget.dealId,
        propertyId: widget.deal['propertyId']?.toString() ?? '',
        brokerId:
            widget.deal['sellerId']?.toString() ??
            widget.deal['brokerId']?.toString() ??
            '',
        amount: (_amount * 0.1).toInt(),
      );
      // Record platform fee
      await FirebaseFirestore.instance.collection('platform_fees').add({
        'dealId': widget.dealId,
        'amount': platformFee,
        'feePercent': 1.5,
        'dealValue': _amount,
        'status': 'pending', // collected on deal close
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Token paid and held in escrow'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Payment failed: $e')));
    } finally {
      if (mounted) setState(() => _payingToken = false);
    }
  }

  String _fmt(int v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)} Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)} L';
    return '₹${NumberFormat('#,##,###').format(v)}';
  }

  @override
  Widget build(BuildContext context) {
    final agreementId = widget.deal['agreementId']?.toString();
    final createdAt = (widget.deal['createdAt'] as Timestamp?)?.toDate();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Property snapshot header ──
          _loadingProperty
              ? _PropertySnapshotSkeleton()
              : _propertyData != null
              ? _PropertySnapshot(data: _propertyData!)
              : const SizedBox.shrink(),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Deal ref + status
                Row(
                  children: [
                    Text(
                      'Offer $_dealRef',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const Spacer(),
                    _StatusBadge(status: _status),
                  ],
                ),

                const SizedBox(height: 6),

                // Offer amount
                Row(
                  children: [
                    Text(
                      'Your offer: ${_fmt(_amount)}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (createdAt != null)
                      Text(
                        DateFormat('d MMM y').format(createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Escrow panel
                _EscrowPanel(dealId: widget.dealId),

                // Agreement link
                if (agreementId != null && agreementId.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AgreementScreen(agreementId: agreementId),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'View Agreement',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Spacer(),
                          Icon(
                            Icons.chevron_right,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Pay token button
                if (_status == 'accepted') ...[
                  const SizedBox(height: 10),
                  _EscrowPayButton(
                    dealId: widget.dealId,
                    amount: _amount,
                    paying: _payingToken,
                    onPay: _payToken,
                  ),
                ],

                const SizedBox(height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// PROPERTY SNAPSHOT — shown inside deal card
// ─────────────────────────────────────────

class _PropertySnapshot extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PropertySnapshot({required this.data});

  @override
  Widget build(BuildContext context) {
    final images = (data['images'] as List? ?? [])
        .map((e) => e.toString())
        .toList();
    final imageUrl = images.isNotEmpty ? images.first : '';
    final title = (data['title'] ?? 'Property').toString();
    final city = (data['city'] ?? '').toString();
    final price = (data['price'] as num?)?.toInt() ?? 0;
    final category = (data['propertyCategory'] ?? 'apartment').toString();
    final bhk = (data['bhk'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imgPlaceholder(),
                  )
                : _imgPlaceholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  city,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (bhk > 0) ...[
                      _MiniChip(label: '$bhk BHK'),
                      const SizedBox(width: 6),
                    ],
                    _MiniChip(label: _catLabel(category)),
                    const Spacer(),
                    if (price > 0)
                      Text(
                        _fmtPrice(price),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
    width: 70,
    height: 70,
    color: Colors.grey.shade200,
    child: const Icon(Icons.home_outlined, color: Colors.grey),
  );

  String _catLabel(String cat) {
    const m = {
      'apartment': 'Apartment',
      'house': 'House',
      'villa': 'Villa',
      'plot': 'Plot',
      'land': 'Land',
      'commercial': 'Commercial',
      'warehouse': 'Warehouse',
    };
    return m[cat] ?? cat;
  }

  String _fmtPrice(int v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(0)}L';
    return '₹$v';
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  const _MiniChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
    );
  }
}

class _PropertySnapshotSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 160,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 12,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// ESCROW PANEL
// ─────────────────────────────────────────

class _EscrowPanel extends StatelessWidget {
  final String dealId;
  const _EscrowPanel({required this.dealId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('escrow')
          .where('dealId', isEqualTo: dealId)
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final data = snap.data!.docs.first.data();
        final status = (data['status'] ?? EscrowState.initiated).toString();
        final amount = (data['amount'] as num?)?.toInt() ?? 0;

        final (color, bg, icon, label) = switch (status) {
          EscrowState.completed => (
            Colors.green.shade700,
            Colors.green.shade50,
            Icons.verified_outlined,
            'Escrow released — deal complete',
          ),
          EscrowState.cancelled => (
            Colors.red.shade700,
            Colors.red.shade50,
            Icons.cancel_outlined,
            'Escrow cancelled',
          ),
          EscrowState.paymentPending => (
            Colors.orange.shade700,
            Colors.orange.shade50,
            Icons.hourglass_top_outlined,
            'Payment pending confirmation',
          ),
          _ => (
            AppColors.primary,
            AppColors.primarySoft,
            Icons.lock_outlined,
            'Held in escrow',
          ),
        };

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₹${_fmt(amount)} $label',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    Text(
                      '10% token · secured by EstateX',
                      style: TextStyle(
                        fontSize: 11,
                        color: color.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmt(int v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(0)}L';
    return NumberFormat('#,##,###').format(v);
  }
}

// ─────────────────────────────────────────
// ESCROW PAY BUTTON
// ─────────────────────────────────────────

class _EscrowPayButton extends StatelessWidget {
  final String dealId;
  final int amount;
  final bool paying;
  final VoidCallback onPay;

  const _EscrowPayButton({
    required this.dealId,
    required this.amount,
    required this.paying,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('escrow')
          .where('dealId', isEqualTo: dealId)
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasData && (snap.data?.docs.isNotEmpty ?? false)) {
          return const SizedBox.shrink();
        }
        final tokenAmount = (amount * 0.1).toInt();
        final fee = (amount * 0.015).toInt();
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: AppButtons.primary,
            onPressed: paying ? null : onPay,
            icon: paying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.lock_outline, size: 18),
            label: Text(
              paying
                  ? 'Processing…'
                  : 'Pay Token + Fee (₹${_fmt(tokenAmount + fee)})',
            ),
          ),
        );
      },
    );
  }

  String _fmt(int v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(0)}L';
    return NumberFormat('#,##,###').format(v);
  }
}

// ─────────────────────────────────────────
// STATUS BADGE
// ─────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (fg, bg, label) = switch (status) {
      'accepted' => (Colors.green.shade700, Colors.green.shade50, 'Accepted'),
      'rejected' => (Colors.red.shade700, Colors.red.shade50, 'Rejected'),
      'counter' => (
        Colors.orange.shade700,
        Colors.orange.shade50,
        'Counter offer',
      ),
      'completed' => (AppColors.primary, AppColors.primarySoft, 'Completed'),
      _ => (Colors.grey.shade600, Colors.grey.shade100, 'Pending'),
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

// ─────────────────────────────────────────
// PAYMENT ROW
// ─────────────────────────────────────────

class _PaymentRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _PaymentRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color ?? AppColors.textSecondary,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: color ?? AppColors.textPrimary,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────

class _EmptyDeals extends StatelessWidget {
  const _EmptyDeals();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.handshake_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            const Text(
              'No offers yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'When you make an offer on a property it will appear here with all deal details.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
