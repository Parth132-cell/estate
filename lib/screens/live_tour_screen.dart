import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/colors.dart';
import 'package:estatex_app/services/live_tour_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LiveTourScreen extends StatelessWidget {
  const LiveTourScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: const Text('Live Tours'),
          backgroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Hosting'),
              Tab(text: 'Joined'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showScheduleSheet(context),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.video_call_outlined),
          label: const Text('Schedule Tour'),
        ),
        body: TabBarView(
          children: [
            _TourTab(stream: LiveTourService().hostedTours(), isHost: true),
            _TourTab(stream: LiveTourService().joinedTours(), isHost: false),
          ],
        ),
      ),
    );
  }

  Future<void> _showScheduleSheet(BuildContext context) async {
    final propertyIdCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime selected = DateTime.now().add(const Duration(hours: 2));

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
                'Schedule a Live Tour',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: propertyIdCtrl,
                decoration: InputDecoration(
                  labelText: 'Property ID',
                  hintText: 'Paste the property ID from the listing',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.home_outlined),
                ),
              ),
              const SizedBox(height: 12),
              // Date/time picker
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: selected,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                  );
                  if (d == null) return;
                  final t = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay.fromDateTime(selected),
                  );
                  if (t == null) return;
                  setSheet(
                    () => selected = DateTime(
                      d.year,
                      d.month,
                      d.day,
                      t.hour,
                      t.minute,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        DateFormat('EEE, d MMM y · h:mm a').format(selected),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'What you will cover during the tour…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: AppButtons.primary,
                  onPressed: () async {
                    final pid = propertyIdCtrl.text.trim();
                    if (pid.isEmpty) return;
                    await LiveTourService().createTour(
                      propertyId: pid,
                      scheduleAt: selected,
                      notes: notesCtrl.text.trim(),
                    );
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tour scheduled'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Schedule', style: TextStyle(fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// TAB
// ─────────────────────────────────────────

class _TourTab extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final bool isHost;

  const _TourTab({required this.stream, required this.isHost});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = [...(snapshot.data?.docs ?? [])]
          ..sort((a, b) {
            final aAt = a.data()['scheduledAt'] as Timestamp?;
            final bAt = b.data()['scheduledAt'] as Timestamp?;
            return (aAt?.millisecondsSinceEpoch ?? 0).compareTo(
              bAt?.millisecondsSinceEpoch ?? 0,
            );
          });

        if (docs.isEmpty) {
          return _EmptyTours(isHost: isHost);
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _TourCard(doc: docs[i], isHost: isHost),
        );
      },
    );
  }
}

// ─────────────────────────────────────────
// TOUR CARD
// ─────────────────────────────────────────

class _TourCard extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool isHost;

  const _TourCard({required this.doc, required this.isHost});

  @override
  State<_TourCard> createState() => _TourCardState();
}

class _TourCardState extends State<_TourCard> {
  bool _busy = false;
  String? _propertyTitle;

  @override
  void initState() {
    super.initState();
    _fetchTitle();
  }

  Future<void> _fetchTitle() async {
    final pid = widget.doc.data()['propertyId']?.toString() ?? '';
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

  Future<void> _action(String status) async {
    final label = switch (status) {
      'live' => 'go live with',
      'completed' => 'mark as completed',
      _ => 'cancel',
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm'),
        content: Text('Are you sure you want to $label this tour?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await LiveTourService().updateStatus(
        tourId: widget.doc.id,
        status: status,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    setState(() => _busy = true);
    try {
      await LiveTourService().joinTour(widget.doc.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Joined tour'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to join: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data();
    final at = (data['scheduledAt'] as Timestamp?)?.toDate();
    final status = (data['status'] ?? 'scheduled').toString();
    final notes = (data['notes'] ?? '').toString();
    final participants = (data['participantIds'] as List? ?? []).length;
    final isLive = status == 'live';
    final isPast =
        at != null && at.isBefore(DateTime.now()) && status != 'live';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isLive
            ? Border.all(color: Colors.red.shade400, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live indicator strip
          if (isLive)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade500,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.fiber_manual_record,
                    color: Colors.white,
                    size: 10,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'LIVE NOW',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _propertyTitle ?? 'Loading property…',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _StatusChip(status: status),
                  ],
                ),
                const SizedBox(height: 6),

                // Time
                if (at != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('EEE, d MMM · h:mm a').format(at),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      // Countdown for upcoming
                      if (!isPast && !isLive) ...[
                        const SizedBox(width: 8),
                        _Countdown(scheduledAt: at),
                      ],
                    ],
                  ),

                // Participants
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.people_outline,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$participants joined',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),

                // Notes
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      notes,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],

                // Actions
                if (!isPast &&
                    status != 'completed' &&
                    status != 'cancelled') ...[
                  const SizedBox(height: 12),
                  _busy
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : widget.isHost
                      ? _HostActions(status: status, onAction: _action)
                      : _GuestActions(status: status, onJoin: _join),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// HOST ACTIONS
// ─────────────────────────────────────────

class _HostActions extends StatelessWidget {
  final String status;
  final ValueChanged<String> onAction;

  const _HostActions({required this.status, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (status == 'scheduled') ...[
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
              ),
              onPressed: () => onAction('live'),
              icon: const Icon(Icons.fiber_manual_record, size: 16),
              label: const Text('Go Live'),
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (status == 'live') ...[
          Expanded(
            child: ElevatedButton.icon(
              style: AppButtons.primary,
              onPressed: () => onAction('completed'),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('End Tour'),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade600,
              side: BorderSide(color: Colors.red.shade300),
            ),
            onPressed: () => onAction('cancelled'),
            child: const Text('Cancel'),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// GUEST ACTIONS
// ─────────────────────────────────────────

class _GuestActions extends StatelessWidget {
  final String status;
  final VoidCallback onJoin;

  const _GuestActions({required this.status, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final isLive = status == 'live';
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: isLive
            ? ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600)
            : AppButtons.primary,
        onPressed: onJoin,
        icon: Icon(
          isLive ? Icons.videocam : Icons.notifications_outlined,
          size: 18,
        ),
        label: Text(isLive ? 'Join Live Tour' : 'Notify Me'),
      ),
    );
  }
}

// ─────────────────────────────────────────
// COUNTDOWN
// ─────────────────────────────────────────

class _Countdown extends StatefulWidget {
  final DateTime scheduledAt;
  const _Countdown({required this.scheduledAt});

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.scheduledAt.difference(DateTime.now());
    _tick();
  }

  void _tick() async {
    await Future.delayed(const Duration(minutes: 1));
    if (!mounted) return;
    setState(() {
      _remaining = widget.scheduledAt.difference(DateTime.now());
    });
    _tick();
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining.isNegative) return const SizedBox.shrink();
    final h = _remaining.inHours;
    final m = _remaining.inMinutes % 60;
    final label = h > 0 ? 'in ${h}h ${m}m' : 'in ${m}m';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// STATUS CHIP
// ─────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      'live' => (Colors.red.shade50, Colors.red.shade700, '🔴 Live'),
      'completed' => (AppColors.primarySoft, AppColors.primary, 'Completed'),
      'cancelled' => (Colors.grey.shade100, Colors.grey.shade600, 'Cancelled'),
      _ => (Colors.amber.shade50, Colors.amber.shade700, 'Scheduled'),
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

class _EmptyTours extends StatelessWidget {
  final bool isHost;
  const _EmptyTours({required this.isHost});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              isHost ? 'No tours scheduled' : 'No joined tours',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isHost
                  ? 'Tap Schedule Tour to create a live video walkthrough for buyers.'
                  : 'Tours you join will appear here.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
