import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/agreements/agreement_screen.dart';
import 'package:estatex_app/colors.dart';
import 'package:estatex_app/services/deal_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class SellerDealsScreen extends StatelessWidget {
  const SellerDealsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Incoming Offers'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: DealServices().brokerDeals(), // seller uses same stream
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

          if (deals.isEmpty) {
            return const _EmptyOffers();
          }

          // Group by status
          final active = deals
              .where(
                (d) => !['completed', 'rejected'].contains(d.data()['status']),
              )
              .toList();
          final closed = deals
              .where(
                (d) => ['completed', 'rejected'].contains(d.data()['status']),
              )
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (active.isNotEmpty) ...[
                _SectionHeader(label: 'Active offers', count: active.length),
                const SizedBox(height: 8),
                ...active.map(
                  (doc) => _OfferCard(dealId: doc.id, deal: doc.data()),
                ),
                const SizedBox(height: 20),
              ],
              if (closed.isNotEmpty) ...[
                _SectionHeader(label: 'Closed', count: closed.length),
                const SizedBox(height: 8),
                ...closed.map(
                  (doc) => _OfferCard(dealId: doc.id, deal: doc.data()),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────
// OFFER CARD
// ─────────────────────────────────────────

class _OfferCard extends StatefulWidget {
  final String dealId;
  final Map<String, dynamic> deal;

  const _OfferCard({required this.dealId, required this.deal});

  @override
  State<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<_OfferCard> {
  bool _busy = false;
  Map<String, dynamic>? _propertyData;
  Map<String, dynamic>? _buyerData;
  bool _historyExpanded = false;

  String get _status => (widget.deal['status'] ?? 'pending').toString();
  int get _amount => (widget.deal['amount'] as num?)?.toInt() ?? 0;
  String get _dealRef => '#${widget.dealId.substring(0, 8).toUpperCase()}';
  bool get _isActive => !['completed', 'rejected'].contains(_status);

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    final pid = widget.deal['propertyId']?.toString() ?? '';
    final buyerId = widget.deal['buyerId']?.toString() ?? '';
    try {
      final results = await Future.wait([
        if (pid.isNotEmpty)
          FirebaseFirestore.instance.collection('properties').doc(pid).get()
        else
          Future.value(null),
        if (buyerId.isNotEmpty)
          FirebaseFirestore.instance.collection('users').doc(buyerId).get()
        else
          Future.value(null),
      ]);
      if (mounted) {
        setState(() {
          _propertyData =
              (results[0] as DocumentSnapshot<Map<String, dynamic>>?)?.data();
          _buyerData = (results[1] as DocumentSnapshot<Map<String, dynamic>>?)
              ?.data();
        });
      }
    } catch (_) {}
  }

  Future<void> _accept() async {
    final ok = await _confirm(
      title: 'Accept offer?',
      body:
          'Accept this offer of ${_fmt(_amount)}? The buyer will be notified and can proceed to pay the token.',
      confirmLabel: 'Accept',
      confirmColor: Colors.green.shade600,
    );
    if (ok != true || !mounted) return;
    await _updateStatus('accepted');
  }

  Future<void> _reject() async {
    final ok = await _confirm(
      title: 'Reject offer?',
      body:
          'Reject this offer of ${_fmt(_amount)}? The buyer will be notified.',
      confirmLabel: 'Reject',
      confirmColor: Colors.red.shade600,
    );
    if (ok != true || !mounted) return;
    await _updateStatus('rejected');
  }

  Future<void> _counter() async {
    // Start counter at listed price
    final listedPrice = (_propertyData?['price'] as num?)?.toInt() ?? _amount;
    int counterAmount = listedPrice;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Make a counter offer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Property mini card
              if (_propertyData != null) _PropertyMini(data: _propertyData!),
              const SizedBox(height: 14),
              _InfoRow(label: 'Buyer offered', value: _fmt(_amount)),
              _InfoRow(label: 'Listed price', value: _fmt(listedPrice)),
              const SizedBox(height: 14),
              const Text(
                'Your counter amount (₹)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              // Amount input
              TextField(
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                controller: TextEditingController(
                  text: counterAmount.toString(),
                ),
                onChanged: (v) =>
                    counterAmount = int.tryParse(v) ?? counterAmount,
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Slider
              Slider(
                value: counterAmount.clamp(_amount, listedPrice * 2).toDouble(),
                min: _amount.toDouble(),
                max: (listedPrice * 1.2).toDouble(),
                activeColor: AppColors.primary,
                onChanged: (v) => setDialog(() => counterAmount = v.round()),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _fmt(_amount),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${_fmt(listedPrice)} (listed)',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              if (counterAmount != _amount) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Difference: ${_fmt((counterAmount - _amount).abs())} ${counterAmount > _amount ? 'more' : 'less'} than offer',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Send ${_fmt(counterAmount)}'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await DealServices().counterOffer(
        dealId: widget.dealId,
        counterAmount: counterAmount,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Counter offer sent: ${_fmt(counterAmount)}'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _busy = true);
    try {
      await DealServices().updateDealStatus(widget.dealId, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Offer ${status}d'),
          backgroundColor: status == 'accepted'
              ? Colors.green.shade700
              : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  String _fmt(int v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)} Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)} L';
    return '₹${NumberFormat('#,##,###').format(v)}';
  }

  @override
  Widget build(BuildContext context) {
    final agreementId = widget.deal['agreementId']?.toString();
    final history = (widget.deal['history'] as List? ?? [])
        .cast<Map<dynamic, dynamic>>();
    final createdAt = (widget.deal['createdAt'] as Timestamp?)?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _status == 'accepted'
              ? Colors.green.shade200
              : _status == 'rejected'
              ? Colors.red.shade100
              : Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Property snapshot ──
          if (_propertyData != null) _PropertySnapshot(data: _propertyData!),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Deal ref + status
                Row(
                  children: [
                    Text(
                      'Offer $_dealRef',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const Spacer(),
                    _StatusBadge(status: _status),
                  ],
                ),

                const SizedBox(height: 8),

                // Amount + buyer name
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _fmt(_amount),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_buyerData != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          'by ${_buyerData!['name'] ?? 'Buyer'}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    const Spacer(),
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

                // Buyer privacy notice
                if (_buyerData != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Buyer contact protected — use EstateX chat',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Escrow status if paid
                _EscrowBadge(dealId: widget.dealId),

                // Actions
                if (_isActive && !_busy) ...[
                  const SizedBox(height: 12),
                  _ActionBar(
                    status: _status,
                    onAccept: _accept,
                    onReject: _reject,
                    onCounter: _counter,
                  ),
                ],

                if (_busy) ...[
                  const SizedBox(height: 12),
                  const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ],

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
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'View Agreement',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Spacer(),
                          Icon(
                            Icons.chevron_right,
                            color: AppColors.primary,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Deal history toggle
                if (history.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _historyExpanded = !_historyExpanded),
                    child: Row(
                      children: [
                        Text(
                          '${history.length} offer event${history.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _historyExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                  if (_historyExpanded) ...[
                    const SizedBox(height: 8),
                    _HistoryTimeline(history: history),
                  ],
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
// ACTION BAR
// ─────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final String status;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onCounter;

  const _ActionBar({
    required this.status,
    required this.onAccept,
    required this.onReject,
    required this.onCounter,
  });

  @override
  Widget build(BuildContext context) {
    if (status == 'accepted') {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
            SizedBox(width: 8),
            Text(
              'Offer accepted — awaiting buyer token payment',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        // Reject
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade600,
              side: BorderSide(color: Colors.red.shade300),
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: onReject,
            child: const Text('Reject'),
          ),
        ),
        const SizedBox(width: 8),
        // Counter
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: onCounter,
            child: const Text('Counter'),
          ),
        ),
        const SizedBox(width: 8),
        // Accept
        Expanded(
          flex: 2,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: onAccept,
            child: const Text(
              'Accept',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// PROPERTY SNAPSHOT — top of card
// ─────────────────────────────────────────

class _PropertySnapshot extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PropertySnapshot({required this.data});

  @override
  Widget build(BuildContext context) {
    final images = (data['images'] as List? ?? [])
        .map((e) => e.toString())
        .toList();
    final title = (data['title'] ?? 'Property').toString();
    final city = (data['city'] ?? '').toString();
    final price = (data['price'] as num?)?.toInt() ?? 0;
    final bhk = (data['bhk'] as num?)?.toInt() ?? 0;
    final cat = (data['propertyCategory'] ?? 'apartment').toString();

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
            child: images.isNotEmpty
                ? Image.network(
                    images.first,
                    width: 68,
                    height: 68,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  city,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    if (bhk > 0) _Chip('$bhk BHK'),
                    if (bhk > 0) const SizedBox(width: 6),
                    _Chip(_catLabel(cat)),
                    const Spacer(),
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

  Widget _placeholder() => Container(
    width: 68,
    height: 68,
    color: Colors.grey.shade200,
    child: const Icon(Icons.home_outlined, color: Colors.grey),
  );

  Widget _Chip(String label) => Container(
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

  String _catLabel(String cat) {
    const m = {
      'apartment': 'Apartment',
      'house': 'House',
      'villa': 'Villa',
      'residential_plot': 'Plot',
      'agricultural_land': 'Land',
      'office_space': 'Office',
      'retail_shop': 'Shop',
      'warehouse': 'Warehouse',
      'pg_hostel': 'PG',
      'flat_rent': 'Rental',
    };
    return m[cat] ?? cat;
  }

  String _fmtPrice(int v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(0)}L';
    return '₹$v';
  }
}

// ─────────────────────────────────────────
// PROPERTY MINI — inside dialog
// ─────────────────────────────────────────

class _PropertyMini extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PropertyMini({required this.data});

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] ?? '').toString();
    final city = (data['city'] ?? '').toString();
    final images = (data['images'] as List? ?? [])
        .map((e) => e.toString())
        .toList();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: images.isNotEmpty
                ? Image.network(
                    images.first,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 48,
                      height: 48,
                      color: Colors.grey.shade200,
                    ),
                  )
                : Container(width: 48, height: 48, color: Colors.grey.shade200),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  city,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
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
// ESCROW BADGE
// ─────────────────────────────────────────

class _EscrowBadge extends StatelessWidget {
  final String dealId;
  const _EscrowBadge({required this.dealId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('escrow')
          .where('dealId', isEqualTo: dealId)
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty)
          return const SizedBox.shrink();
        final data = snap.data!.docs.first.data();
        final status = (data['status'] ?? '').toString();
        final amount = (data['amount'] as num?)?.toInt() ?? 0;

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: status == 'completed'
                ? Colors.green.shade50
                : Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: status == 'completed'
                  ? Colors.green.shade200
                  : Colors.amber.shade200,
            ),
          ),
          child: Row(
            children: [
              Icon(
                status == 'completed'
                    ? Icons.verified_outlined
                    : Icons.lock_outline,
                size: 16,
                color: status == 'completed'
                    ? Colors.green.shade700
                    : Colors.amber.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                status == 'completed'
                    ? '₹${_fmt(amount)} escrow released'
                    : '₹${_fmt(amount)} token held in escrow',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: status == 'completed'
                      ? Colors.green.shade700
                      : Colors.amber.shade800,
                ),
              ),
            ],
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
// HISTORY TIMELINE
// ─────────────────────────────────────────

class _HistoryTimeline extends StatelessWidget {
  final List<Map<dynamic, dynamic>> history;
  const _HistoryTimeline({required this.history});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: history.asMap().entries.map((entry) {
        final i = entry.key;
        final item = Map<String, dynamic>.from(entry.value);
        final action = (item['action'] ?? '').toString();
        final amount = item['amount'];
        final status = item['status'];
        final at = item['at'] is Timestamp
            ? (item['at'] as Timestamp).toDate()
            : null;

        final detail = amount != null
            ? '₹${_fmtAmt((amount as num).toInt())}'
            : status?.toString() ?? '';

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == 0 ? AppColors.primary : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                ),
                if (i < history.length - 1)
                  Container(width: 1, height: 24, color: Colors.grey.shade200),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$action${detail.isNotEmpty ? ' · $detail' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (at != null)
                      Text(
                        DateFormat('d MMM').format(at),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  String _fmtAmt(int v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(0)}L';
    return NumberFormat('#,##,###').format(v);
  }
}

// ─────────────────────────────────────────
// HELPERS
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
        'Counter sent',
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

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyOffers extends StatelessWidget {
  const _EmptyOffers();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
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
              'When buyers make offers on your properties they will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
