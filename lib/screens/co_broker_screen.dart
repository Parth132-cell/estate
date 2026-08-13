import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/colors.dart';
import 'package:estatex_app/services/co_broker_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CoBrokerScreen extends StatelessWidget {
  const CoBrokerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: const Text('Co-broker Collaboration'),
          backgroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'My Deals'),
              Tab(text: 'Assigned to Me'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _MyDealsTab(brokerId: uid),
            _AssignedTab(brokerId: uid),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// MY DEALS TAB — deals I own, can assign
// ─────────────────────────────────────────

class _MyDealsTab extends StatelessWidget {
  final String brokerId;
  const _MyDealsTab({required this.brokerId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('offers')
          .where('sellerId', isEqualTo: brokerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = [...(snapshot.data?.docs ?? [])]
          ..sort((a, b) {
            final aAt = a.data()['createdAt'] as Timestamp?;
            final bAt = b.data()['createdAt'] as Timestamp?;
            return (bAt?.millisecondsSinceEpoch ?? 0).compareTo(
              aAt?.millisecondsSinceEpoch ?? 0,
            );
          });

        if (docs.isEmpty) {
          return _EmptyState(
            icon: Icons.handshake_outlined,
            title: 'No deals yet',
            subtitle:
                'Your active deals will appear here once buyers make offers.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _DealCard(doc: docs[i], isOwner: true),
        );
      },
    );
  }
}

// ─────────────────────────────────────────
// ASSIGNED TO ME TAB
// ─────────────────────────────────────────

class _AssignedTab extends StatelessWidget {
  final String brokerId;
  const _AssignedTab({required this.brokerId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('offers')
          .where('coBrokerId', isEqualTo: brokerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptyState(
            icon: Icons.group_outlined,
            title: 'No assignments yet',
            subtitle:
                'When another broker assigns you to a deal it will appear here.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _DealCard(doc: docs[i], isOwner: false),
        );
      },
    );
  }
}

// ─────────────────────────────────────────
// DEAL CARD
// ─────────────────────────────────────────

class _DealCard extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool isOwner;

  const _DealCard({required this.doc, required this.isOwner});

  @override
  State<_DealCard> createState() => _DealCardState();
}

class _DealCardState extends State<_DealCard> {
  bool _busy = false;
  String? _propertyTitle;

  Map<String, dynamic> get _data => widget.doc.data();
  String get _coBrokerId => (_data['coBrokerId'] ?? '').toString();
  String get _coBrokerStatus =>
      (_data['coBrokerStatus'] ?? 'not_assigned').toString();
  int get _split => (_data['coBrokerSplitPercent'] as num?)?.toInt() ?? 0;
  int get _amount => (_data['amount'] as num?)?.toInt() ?? 0;

  @override
  void initState() {
    super.initState();
    _fetchTitle();
  }

  Future<void> _fetchTitle() async {
    final pid = _data['propertyId']?.toString() ?? '';
    if (pid.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('properties')
          .doc(pid)
          .get();
      if (mounted) {
        setState(() => _propertyTitle = snap.data()?['title']?.toString());
      }
    } catch (_) {}
  }

  Future<void> _openAssignDialog() async {
    final searchCtrl = TextEditingController();
    double split = 50;
    String? selectedBrokerId;
    String? selectedBrokerName;
    List<Map<String, dynamic>> results = [];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Assign Co-broker',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Search
              TextField(
                controller: searchCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Search broker by name or phone',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () async {
                      final q = searchCtrl.text.trim();
                      if (q.isEmpty) return;
                      final snap = await FirebaseFirestore.instance
                          .collection('users')
                          .where('role', isEqualTo: 'broker')
                          .get();
                      final filtered = snap.docs
                          .where((d) {
                            final n = (d.data()['name'] ?? '')
                                .toString()
                                .toLowerCase();
                            final p = (d.data()['phone'] ?? '').toString();
                            return n.contains(q.toLowerCase()) || p.contains(q);
                          })
                          .map((d) => {'id': d.id, ...d.data()})
                          .toList();
                      setSheet(() => results = filtered);
                    },
                  ),
                ),
              ),

              // Results
              if (results.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...results
                    .take(5)
                    .map(
                      (b) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primarySoft,
                          child: Text(
                            (b['name'] ?? '?')
                                .toString()
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(color: AppColors.primary),
                          ),
                        ),
                        title: Text(b['name']?.toString() ?? '-'),
                        subtitle: Text(b['phone']?.toString() ?? ''),
                        trailing: selectedBrokerId == b['id']
                            ? const Icon(
                                Icons.check_circle,
                                color: AppColors.primary,
                              )
                            : null,
                        onTap: () => setSheet(() {
                          selectedBrokerId = b['id'].toString();
                          selectedBrokerName = b['name']?.toString();
                        }),
                      ),
                    ),
              ],

              if (selectedBrokerName != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Selected: $selectedBrokerName',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Split slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Commission split',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${split.toInt()}% to co-broker',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Slider(
                value: split,
                min: 10,
                max: 90,
                divisions: 16,
                activeColor: AppColors.primary,
                label: '${split.toInt()}%',
                onChanged: (v) => setSheet(() => split = v),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'You keep ${(100 - split).toInt()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Co-broker gets ${split.toInt()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: AppButtons.primary,
                  onPressed: selectedBrokerId == null
                      ? null
                      : () async {
                          await CoBrokerService().assignCoBroker(
                            offerId: widget.doc.id,
                            coBrokerId: selectedBrokerId!,
                            splitPercent: split.toInt(),
                          );
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                        },
                  child: const Text(
                    'Assign Co-broker',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _respond(String response) async {
    setState(() => _busy = true);
    try {
      await CoBrokerService().respondToAssignment(
        offerId: widget.doc.id,
        response: response,
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

  String _fmt(int v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final hasAssignment = _coBrokerId.isNotEmpty;
    final commissionAmt = hasAssignment ? (_amount * _split / 100).round() : 0;

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
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Property title + deal amount
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _propertyTitle ?? 'Loading…',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Deal value: ₹${_fmt(_amount)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _CoBrokerStatusChip(status: _coBrokerStatus),
            ],
          ),

          const SizedBox(height: 10),

          // Co-broker info
          if (hasAssignment) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Co-broker assigned · $_split% split',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (commissionAmt > 0)
                    Text(
                      '₹${_fmt(commissionAmt)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Actions
          if (_busy)
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (widget.isOwner && !hasAssignment)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: AppButtons.primary,
                onPressed: _openAssignDialog,
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: const Text('Assign Co-broker'),
              ),
            )
          else if (!widget.isOwner && _coBrokerStatus == 'pending') ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                    ),
                    onPressed: () => _respond('accepted'),
                    child: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      side: BorderSide(color: Colors.red.shade300),
                    ),
                    onPressed: () => _respond('declined'),
                    child: const Text('Decline'),
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

// ─────────────────────────────────────────
// CO-BROKER STATUS CHIP
// ─────────────────────────────────────────

class _CoBrokerStatusChip extends StatelessWidget {
  final String status;
  const _CoBrokerStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      'accepted' => (Colors.green.shade50, Colors.green.shade700, 'Active'),
      'declined' => (Colors.red.shade50, Colors.red.shade700, 'Declined'),
      'pending' => (Colors.amber.shade50, Colors.amber.shade700, 'Pending'),
      'completed' => (AppColors.primarySoft, AppColors.primary, 'Completed'),
      _ => (Colors.grey.shade100, Colors.grey.shade600, 'Unassigned'),
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
// EMPTY STATE
// ─────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
