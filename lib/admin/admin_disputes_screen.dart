import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/colors.dart';
import 'package:estatex_app/services/dispute_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminDisputesScreen extends StatelessWidget {
  const AdminDisputesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: const Text('Dispute Resolution'),
          backgroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Open'),
              Tab(text: 'Escalated'),
              Tab(text: 'Resolved'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _DisputeList(status: 'open'),
            _DisputeList(status: 'escalated'),
            _DisputeList(status: 'resolved'),
          ],
        ),
      ),
    );
  }
}

class _DisputeList extends StatelessWidget {
  final String status;
  const _DisputeList({required this.status});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: DisputeService().disputesByStatus(status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptyDisputes(status: status);
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _DisputeCard(doc: docs[i]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────
// DISPUTE CARD
// ─────────────────────────────────────────

class _DisputeCard extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _DisputeCard({required this.doc});

  @override
  State<_DisputeCard> createState() => _DisputeCardState();
}

class _DisputeCardState extends State<_DisputeCard> {
  bool _busy = false;
  String? _buyerName;
  String? _sellerName;

  Map<String, dynamic> get _data => widget.doc.data();
  String get _status => (_data['status'] ?? 'open').toString();
  String get _dealId => (_data['dealId'] ?? '-').toString();
  String get _reason => (_data['reason'] ?? '-').toString();

  @override
  void initState() {
    super.initState();
    _fetchNames();
  }

  Future<void> _fetchNames() async {
    final buyerId = _data['buyerId']?.toString() ?? '';
    final sellerId = _data['sellerId']?.toString() ?? '';
    try {
      if (buyerId.isNotEmpty) {
        final s = await FirebaseFirestore.instance
            .collection('users')
            .doc(buyerId)
            .get();
        if (mounted) setState(() => _buyerName = s.data()?['name']?.toString());
      }
      if (sellerId.isNotEmpty) {
        final s = await FirebaseFirestore.instance
            .collection('users')
            .doc(sellerId)
            .get();
        if (mounted)
          setState(() => _sellerName = s.data()?['name']?.toString());
      }
    } catch (_) {}
  }

  Future<void> _resolve() async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolve Dispute'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deal: ${_dealId.length > 16 ? _dealId.substring(0, 16) + '…' : _dealId}',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text('Resolution notes:'),
            const SizedBox(height: 6),
            TextField(
              controller: noteCtrl,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Describe the decision and outcome for both parties…',
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark Resolved'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _doAction(
      () => DisputeService().resolve(
        disputeId: widget.doc.id,
        resolution: noteCtrl.text.trim().isNotEmpty
            ? noteCtrl.text.trim()
            : 'Resolved by admin',
      ),
    );
  }

  Future<void> _escalate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Escalate Dispute'),
        content: const Text(
          'Mark this dispute as escalated for senior review?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Escalate'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _doAction(() => DisputeService().escalate(widget.doc.id));
  }

  Future<void> _doAction(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = (_data['createdAt'] as Timestamp?)?.toDate();

    final (bg, border, statusColor, statusLabel) = switch (_status) {
      'escalated' => (
        Colors.orange.shade50,
        Colors.orange.shade200,
        Colors.orange.shade700,
        'Escalated',
      ),
      'resolved' => (
        Colors.grey.shade50,
        Colors.grey.shade200,
        Colors.grey.shade600,
        'Resolved',
      ),
      _ => (
        Colors.red.shade50,
        Colors.red.shade200,
        Colors.red.shade700,
        'Open',
      ),
    };

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status + date
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
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

          const SizedBox(height: 10),

          // Reason
          Text(
            _reason,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 8),

          // Parties
          _PartyRow(label: 'Buyer', name: _buyerName),
          const SizedBox(height: 4),
          _PartyRow(label: 'Seller', name: _sellerName),

          // Deal ID
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Deal: ${_dealId.length > 20 ? _dealId.substring(0, 20) + '…' : _dealId}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          // Resolution note
          if (_status == 'resolved' &&
              (_data['resolution'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '📝 ${_data['resolution']}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
          ],

          // Actions
          if (_status != 'resolved') ...[
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
                      if (_status == 'open') ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange.shade700,
                              side: BorderSide(color: Colors.orange.shade300),
                            ),
                            onPressed: _escalate,
                            icon: const Icon(Icons.arrow_upward, size: 16),
                            label: const Text('Escalate'),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                          ),
                          onPressed: _resolve,
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Resolve'),
                        ),
                      ),
                    ],
                  ),
          ],
        ],
      ),
    );
  }
}

class _PartyRow extends StatelessWidget {
  final String label;
  final String? name;
  const _PartyRow({required this.label, this.name});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          label == 'Buyer' ? Icons.person_outline : Icons.home_work_outlined,
          size: 14,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ${name ?? 'Loading…'}',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _EmptyDisputes extends StatelessWidget {
  final String status;
  const _EmptyDisputes({required this.status});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gavel_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No $status disputes',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Disputes raised by buyers or sellers will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
