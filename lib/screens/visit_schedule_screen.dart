import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/services/visit_schedule_service.dart';
import 'package:flutter/material.dart';

class VisitScheduleScreen extends StatelessWidget {
  final String? initialPropertyId;
  final String? initialBrokerId;

  const VisitScheduleScreen({
    super.key,
    this.initialPropertyId,
    this.initialBrokerId,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Visit Scheduler'),
          bottom: const TabBar(tabs: [Tab(text: 'Buyer'), Tab(text: 'Broker')]),
        ),
        body: TabBarView(
          children: [
            _VisitList(stream: VisitScheduleService().buyerVisits(), isBroker: false),
            _VisitList(stream: VisitScheduleService().brokerVisits(), isBroker: true),
          ],
        ),
        floatingActionButton: (initialPropertyId != null && initialBrokerId != null)
            ? FloatingActionButton.extended(
                onPressed: () => _scheduleVisit(context),
                icon: const Icon(Icons.add),
                label: const Text('Schedule'),
              )
            : null,
      ),
    );
  }

  Future<void> _scheduleVisit(BuildContext context) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null || !context.mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 11, minute: 0),
    );
    if (pickedTime == null || !context.mounted) return;

    final noteCtrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Note (Optional)'),
        content: TextField(
          controller: noteCtrl,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Parking details, gate number, etc.'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Skip')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, noteCtrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    final when = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    try {
      await VisitScheduleService().scheduleVisit(
        propertyId: initialPropertyId!,
        brokerId: initialBrokerId!,
        when: when,
        note: note ?? '',
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Visit request submitted')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to schedule visit: $e')),
      );
    }
  }
}

class _VisitList extends StatefulWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final bool isBroker;

  const _VisitList({required this.stream, required this.isBroker});

  @override
  State<_VisitList> createState() => _VisitListState();
}

class _VisitListState extends State<_VisitList> {
  String? _updatingRequestId;

  Future<void> _updateStatus(String requestId, String status) async {
    setState(() => _updatingRequestId = requestId);
    try {
      await VisitScheduleService().updateStatus(requestId: requestId, status: status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Visit status updated to $status')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update visit: $e')),
      );
    } finally {
      if (mounted) setState(() => _updatingRequestId = null);
    }
  }

  String _fmt(DateTime? dateTime) {
    if (dateTime == null) return '-';
    final mm = dateTime.month.toString().padLeft(2, '0');
    final dd = dateTime.day.toString().padLeft(2, '0');
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final min = dateTime.minute.toString().padLeft(2, '0');
    return '${dateTime.year}-$mm-$dd $hh:$min';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Unable to load visits: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text(widget.isBroker ? 'No broker visits yet' : 'No visits scheduled yet'),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final at = (data['scheduledAt'] as Timestamp?)?.toDate();
            final status = (data['status'] ?? 'requested').toString();
            final note = (data['note'] ?? '').toString();
            final isUpdating = _updatingRequestId == doc.id;

            return Card(
              margin: const EdgeInsets.all(10),
              child: ListTile(
                title: Text('Property: ${data['propertyId'] ?? '-'}'),
                subtitle: Text('Time: ${_fmt(at)}\nStatus: $status\nNote: ${note.isEmpty ? '-' : note}'),
                trailing: widget.isBroker
                    ? isUpdating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : PopupMenuButton<String>(
                            onSelected: (value) => _updateStatus(doc.id, value),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'approved', child: Text('Approve')),
                              PopupMenuItem(value: 'completed', child: Text('Complete')),
                              PopupMenuItem(value: 'cancelled', child: Text('Cancel')),
                            ],
                          )
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}
