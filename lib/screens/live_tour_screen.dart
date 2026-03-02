import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/services/live_tour_service.dart';
import 'package:flutter/material.dart';

class LiveTourScreen extends StatelessWidget {
  const LiveTourScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Live Tours'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Hosted'),
              Tab(text: 'Joined'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openCreateTourDialog(context),
          icon: const Icon(Icons.video_call_outlined),
          label: const Text('Schedule Tour'),
        ),
        body: TabBarView(
          children: [
            _TourList(stream: LiveTourService().hostedTours(), isHost: true),
            _TourList(stream: LiveTourService().joinedTours(), isHost: false),
          ],
        ),
      ),
    );
  }

  Future<void> _openCreateTourDialog(BuildContext context) async {
    final propertyCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime selected = DateTime.now().add(const Duration(hours: 2));

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Schedule Live Tour'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: propertyCtrl,
                decoration: const InputDecoration(labelText: 'Property ID'),
              ),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: Text('At: ${selected.toLocal()}')),
                  TextButton(
                    child: const Text('Pick'),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: selected,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 60)),
                      );
                      if (d == null) return;
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selected),
                      );
                      if (t == null) return;
                      setLocalState(() {
                        selected = DateTime(d.year, d.month, d.day, t.hour, t.minute);
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (propertyCtrl.text.trim().isEmpty) return;
                await LiveTourService().createTour(
                  propertyId: propertyCtrl.text.trim(),
                  scheduleAt: selected,
                  notes: notesCtrl.text.trim(),
                );
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TourList extends StatelessWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final bool isHost;

  const _TourList({required this.stream, required this.isHost});

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
            child: Text(isHost ? 'No hosted tours yet' : 'No joined tours yet'),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final at = (data['scheduledAt'] as Timestamp?)?.toDate();
            final status = (data['status'] ?? 'scheduled').toString();

            return Card(
              margin: const EdgeInsets.all(10),
              child: ListTile(
                title: Text('Property: ${data['propertyId'] ?? '-'}'),
                subtitle: Text(
                  'Time: ${at ?? '-'}\nStatus: $status\nNotes: ${data['notes'] ?? ''}',
                ),
                trailing: isHost
                    ? PopupMenuButton<String>(
                        onSelected: (value) {
                          LiveTourService().updateStatus(tourId: doc.id, status: value);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'live', child: Text('Mark Live')),
                          PopupMenuItem(value: 'completed', child: Text('Mark Completed')),
                          PopupMenuItem(value: 'cancelled', child: Text('Cancel')),
                        ],
                      )
                    : TextButton(
                        onPressed: () => LiveTourService().joinTour(doc.id),
                        child: const Text('Join'),
                      ),
              ),
            );
          },
        );
      },
    );
  }
}
