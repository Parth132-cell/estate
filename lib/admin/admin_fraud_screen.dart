import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/colors.dart';
import 'package:estatex_app/services/fraud_detection_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class AdminFraudScreen extends StatefulWidget {
  const AdminFraudScreen({super.key});

  @override
  State<AdminFraudScreen> createState() => _AdminFraudScreenState();
}

class _AdminFraudScreenState extends State<AdminFraudScreen> {
  bool _scanning = false;
  String _filterSeverity = 'all';

  Future<void> _runScan() async {
    setState(() => _scanning = true);
    try {
      final count = await FraudDetectionService().scanAndCreateAlerts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan complete — $count alert(s) created'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan failed: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Fraud Detection'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Severity filter
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by severity',
            onSelected: (v) => setState(() => _filterSeverity = v),
            itemBuilder: (_) => [
              for (final s in ['all', 'high', 'medium', 'low'])
                PopupMenuItem(
                  value: s,
                  child: Text(
                    s == 'all' ? 'All' : s[0].toUpperCase() + s.substring(1),
                  ),
                ),
            ],
          ),
          // Scan button
          IconButton(
            icon: _scanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.playlist_add_check_circle_outlined),
            tooltip: 'Run Scan',
            onPressed: _scanning ? null : _runScan,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FraudDetectionService().alerts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          var docs = snapshot.data?.docs ?? [];

          // Filter
          if (_filterSeverity != 'all') {
            docs = docs
                .where(
                  (d) =>
                      (d.data()['severity'] ?? '').toString() ==
                      _filterSeverity,
                )
                .toList();
          }

          // Sort: open first, then by severity
          final severityOrder = {'high': 0, 'medium': 1, 'low': 2};
          docs = [...docs]
            ..sort((a, b) {
              final aOpen = a.data()['status'] == 'resolved' ? 1 : 0;
              final bOpen = b.data()['status'] == 'resolved' ? 1 : 0;
              if (aOpen != bOpen) return aOpen.compareTo(bOpen);
              final as_ = severityOrder[a.data()['severity']] ?? 3;
              final bs_ = severityOrder[b.data()['severity']] ?? 3;
              return as_.compareTo(bs_);
            });

          if (docs.isEmpty) {
            return _EmptyFraud(filtered: _filterSeverity != 'all');
          }

          // Summary counts
          final openHigh = docs
              .where(
                (d) =>
                    d.data()['status'] != 'resolved' &&
                    d.data()['severity'] == 'high',
              )
              .length;
          final openTotal = docs
              .where((d) => d.data()['status'] != 'resolved')
              .length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary banner
              if (openHigh > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_rounded,
                        color: Colors.red.shade700,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$openHigh high-severity alert${openHigh > 1 ? 's' : ''} require immediate attention',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (openTotal > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Text(
                    '$openTotal open alert${openTotal > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ),

              ...docs.map(
                (doc) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _FraudAlertCard(doc: doc),
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
// FRAUD ALERT CARD
// ─────────────────────────────────────────

class _FraudAlertCard extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _FraudAlertCard({required this.doc});

  @override
  State<_FraudAlertCard> createState() => _FraudAlertCardState();
}

class _FraudAlertCardState extends State<_FraudAlertCard> {
  bool _loadingAnalysis = false;
  String? _aiAnalysis;
  bool _busy = false;
  bool _expanded = false;

  Map<String, dynamic> get _data => widget.doc.data();
  String get _severity => (_data['severity'] ?? 'low').toString();
  String get _status => (_data['status'] ?? 'open').toString();
  bool get _resolved => _status == 'resolved';

  Future<void> _getAiAnalysis() async {
    if (!mounted) return;
    setState(() {
      _loadingAnalysis = true;
      _expanded = true;
    });

    final prompt =
        '''
You are a fraud analyst for an Indian real estate platform called EstateX.
Analyze this fraud alert and give a brief assessment.

Alert data:
- Entity type: ${_data['entityType']}
- Entity ID: ${_data['entityId']}
- Reason: ${_data['reason']}
- Severity: $_severity
- Status: $_status
- Created: ${_data['createdAt']}

Give a 2-3 sentence analysis: what likely happened, what risk it poses, and what the admin should do.
Keep it direct and actionable. No bullet points, plain prose.
''';

    try {
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'claude-sonnet-4-6',
          'max_tokens': 1000,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final text = (body['content'] as List)
            .whereType<Map>()
            .where((b) => b['type'] == 'text')
            .map((b) => b['text'].toString())
            .join('');
        setState(() => _aiAnalysis = text.trim());
      } else {
        setState(() => _aiAnalysis = 'Analysis unavailable right now.');
      }
    } catch (_) {
      if (mounted)
        setState(() => _aiAnalysis = 'Analysis unavailable right now.');
    } finally {
      if (mounted) setState(() => _loadingAnalysis = false);
    }
  }

  Future<void> _resolve() async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolve Alert'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add a resolution note (optional):'),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'e.g. Verified legitimate listing, false positive',
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
    setState(() => _busy = true);
    try {
      await FraudDetectionService().resolveAlert(
        widget.doc.id,
        resolution: noteCtrl.text.trim(),
      );
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
    final (bg, border, severityColor, severityLabel) = switch (_severity) {
      'high' => (
        Colors.red.shade50,
        Colors.red.shade200,
        Colors.red.shade700,
        'HIGH',
      ),
      'medium' => (
        Colors.orange.shade50,
        Colors.orange.shade200,
        Colors.orange.shade700,
        'MEDIUM',
      ),
      _ => (
        Colors.blue.shade50,
        Colors.blue.shade200,
        Colors.blue.shade700,
        'LOW',
      ),
    };

    final createdAt = (_data['createdAt'] as Timestamp?)?.toDate();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _resolved ? Colors.grey.shade50 : bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _resolved ? Colors.grey.shade200 : border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _resolved ? Colors.grey.shade200 : severityColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _resolved ? 'RESOLVED' : severityLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_data['entityType'] ?? 'Unknown'} · ${(_data['entityId'] ?? '').toString().length > 12 ? (_data['entityId'] ?? '').toString().substring(0, 12) + '…' : _data['entityId'] ?? '-'}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (createdAt != null)
                      Text(
                        DateFormat('d MMM').format(createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 8),

                // Reason
                Text(
                  _data['reason']?.toString() ?? '-',
                  style: TextStyle(
                    fontSize: 13,
                    color: _resolved
                        ? Colors.grey.shade500
                        : AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),

                // Resolution note
                if (_resolved &&
                    (_data['resolution'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notes,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _data['resolution'].toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // AI Analysis (expanded)
                if (_expanded) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: _loadingAnalysis
                        ? Row(
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Claude is analysing…',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.auto_awesome,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'AI Analysis',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _aiAnalysis ?? '',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],

                // Actions
                if (!_resolved) ...[
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
                            // AI analyse button
                            if (_aiAnalysis == null)
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _loadingAnalysis
                                      ? null
                                      : _getAiAnalysis,
                                  icon: const Icon(
                                    Icons.auto_awesome,
                                    size: 16,
                                  ),
                                  label: const Text('AI Analyse'),
                                ),
                              ),
                            if (_aiAnalysis == null) const SizedBox(width: 8),
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
          ),
        ],
      ),
    );
  }
}

class _EmptyFraud extends StatelessWidget {
  final bool filtered;
  const _EmptyFraud({required this.filtered});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              filtered ? 'No alerts for this severity' : 'No fraud alerts',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              filtered
                  ? 'Try changing the severity filter.'
                  : 'Run a scan to check for suspicious activity.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
