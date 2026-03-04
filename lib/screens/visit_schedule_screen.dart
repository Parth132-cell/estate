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

    final when = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    await VisitScheduleService().scheduleVisit(
      propertyId: initialPropertyId!,
      brokerId: initialBrokerId!,
      when: when,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Visit request submitted')),
    );
  }
}

class _VisitList extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final bool isBroker;

  const _VisitList({required this.stream, required this.isBroker});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text(isBroker ? 'No broker visits yet' : 'No visits scheduled yet'),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final at = (data['scheduledAt'] as Timestamp?)?.toDate();
            final status = (data['status'] ?? 'requested').toString();

            return Card(
              margin: const EdgeInsets.all(10),
              child: ListTile(
                title: Text('Property: ${data['propertyId'] ?? '-'}'),
                subtitle: Text('Time: ${at ?? '-'}\nStatus: $status\nNote: ${data['note'] ?? ''}'),
                trailing: isBroker
                    ? PopupMenuButton<String>(
                        onSelected: (v) => VisitScheduleService().updateStatus(requestId: doc.id, status: v),
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
