import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/admin/admin_broker_approval_screen.dart';
import 'package:estatex_app/admin/admin_disputes_screen.dart';
import 'package:estatex_app/admin/admin_fraud_screen.dart';
import 'package:estatex_app/admin/admin_revenue_screen.dart';
import 'package:estatex_app/app_theme.dart';
import 'package:estatex_app/colors.dart';
import 'package:flutter/material.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1D4ED8), Color(0xFF4F46E5)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.admin_panel_settings_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'EstateX Admin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Live metrics
                _AdminMetricsRow(),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Section: Revenue ──
          _SectionLabel(label: 'Revenue'),
          _AdminTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Revenue Dashboard',
            subtitle: 'Transaction fees, subscriptions, featured listings',
            color: Colors.green.shade700,
            bg: Colors.green.shade50,
            onTap: () => _push(context, const AdminRevenueScreen()),
          ),

          const SizedBox(height: 16),

          // ── Section: Verification ──
          _SectionLabel(label: 'Verification'),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('admin_notifications')
                .where('type', isEqualTo: 'broker_application')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snap) {
              final pendingCount = snap.data?.docs.length ?? 0;
              return _AdminTile(
                icon: Icons.how_to_reg_outlined,
                title: 'Broker Applications',
                subtitle: 'Review RERA registrations, approve or reject',
                color: const Color(0xFF7C3AED),
                bg: const Color(0xFFF5F3FF),
                badgeCount: pendingCount,
                onTap: () => _push(context, const AdminBrokerApprovalScreen()),
              );
            },
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('properties')
                .where('verificationStatus', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snap) {
              final pendingCount = snap.data?.docs.length ?? 0;
              return _AdminTile(
                icon: Icons.home_work_outlined,
                title: 'Property Approvals',
                subtitle: 'Review and verify property listings',
                color: AppColors.primary,
                bg: AppColors.primarySoft,
                badgeCount: pendingCount,
                onTap: () => _push(context, const _PropertyApprovalsScreen()),
              );
            },
          ),

          const SizedBox(height: 16),

          // ── Section: Trust & Safety ──
          _SectionLabel(label: 'Trust & Safety'),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('disputes')
                .where('status', isEqualTo: 'open')
                .snapshots(),
            builder: (context, snap) {
              final count = snap.data?.docs.length ?? 0;
              return _AdminTile(
                icon: Icons.gavel_outlined,
                title: 'Disputes',
                subtitle: 'Open, escalated and resolved disputes',
                color: Colors.orange.shade700,
                bg: Colors.orange.shade50,
                badgeCount: count,
                onTap: () => _push(context, const AdminDisputesScreen()),
              );
            },
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('fraud_alerts')
                .where('status', isEqualTo: 'open')
                .snapshots(),
            builder: (context, snap) {
              final count = snap.data?.docs.length ?? 0;
              return _AdminTile(
                icon: Icons.security_outlined,
                title: 'Fraud Detection',
                subtitle: 'Scan and review suspicious activity',
                color: Colors.red.shade700,
                bg: Colors.red.shade50,
                badgeCount: count,
                onTap: () => _push(context, const AdminFraudScreen()),
              );
            },
          ),

          const SizedBox(height: 16),

          // ── Section: Platform ──
          _SectionLabel(label: 'Platform'),
          _AdminTile(
            icon: Icons.people_outlined,
            title: 'Users',
            subtitle: 'All registered buyers, sellers and brokers',
            color: Colors.teal.shade700,
            bg: Colors.teal.shade50,
            onTap: () {},
          ),
          _AdminTile(
            icon: Icons.bar_chart_outlined,
            title: 'Analytics',
            subtitle: 'App usage, traffic and conversion metrics',
            color: Colors.indigo.shade700,
            bg: Colors.indigo.shade50,
            onTap: () {},
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

// ─────────────────────────────────────────
// LIVE METRICS ROW
// ─────────────────────────────────────────

class _AdminMetricsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: _fetchCounts(),
      builder: (context, snap) {
        final counts = snap.data ?? [0, 0, 0];
        return Row(
          children: [
            _MetricItem(label: 'Users', value: '${counts[0]}'),
            _MetricItem(label: 'Properties', value: '${counts[1]}'),
            _MetricItem(label: 'Deals', value: '${counts[2]}'),
          ],
        );
      },
    );
  }

  Future<List<int>> _fetchCounts() async {
    final db = FirebaseFirestore.instance;
    final results = await Future.wait([
      db.collection('users').count().get(),
      db.collection('properties').count().get(),
      db.collection('offers').count().get(),
    ]);
    return results.map((r) => r.count ?? 0).toList();
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final String value;

  const _MetricItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// ADMIN TILE
// ─────────────────────────────────────────

class _AdminTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color bg;
  final int badgeCount;
  final VoidCallback onTap;

  const _AdminTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.bg,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
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
            if (badgeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade500,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Icon(Icons.chevron_right, color: Colors.grey.shade300, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade400,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// PROPERTY APPROVALS SCREEN (inline)
// ─────────────────────────────────────────

class _PropertyApprovalsScreen extends StatelessWidget {
  const _PropertyApprovalsScreen();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Property Approvals'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
              Tab(text: 'Rejected'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PropertyList(status: 'pending'),
            _PropertyList(status: 'approved'),
            _PropertyList(status: 'rejected'),
          ],
        ),
      ),
    );
  }
}

class _PropertyList extends StatelessWidget {
  final String status;
  const _PropertyList({required this.status});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('properties')
          .where('verificationStatus', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text(
              'No $status properties',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data();
            final id = docs[i].id;
            final title = (data['title'] ?? 'Untitled').toString();
            final city = (data['city'] ?? '').toString();
            final price = (data['price'] as num?)?.toInt() ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '$city · ₹${_fmt(price)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (status == 'pending')
                    Row(
                      children: [
                        _ActionBtn(
                          label: 'Reject',
                          color: Colors.red.shade600,
                          onTap: () => _reject(context, id),
                        ),
                        const SizedBox(width: 8),
                        _ActionBtn(
                          label: 'Approve',
                          color: Colors.green.shade600,
                          onTap: () => _approve(context, id),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _fmt(int v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(0)}L';
    return '$v';
  }

  Future<void> _approve(BuildContext context, String id) async {
    await FirebaseFirestore.instance.collection('properties').doc(id).update({
      'verificationStatus': 'approved',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Property approved'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _reject(BuildContext context, String id) async {
    await FirebaseFirestore.instance.collection('properties').doc(id).update({
      'verificationStatus': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Property rejected'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
