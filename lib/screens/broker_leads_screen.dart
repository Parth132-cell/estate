import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/services/lead_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BrokerLeadsScreen extends StatefulWidget {
  const BrokerLeadsScreen({super.key});

  @override
  State<BrokerLeadsScreen> createState() => _BrokerLeadsScreenState();
}

class _BrokerLeadsScreenState extends State<BrokerLeadsScreen> {
  String? _updatingLeadId;
  String _statusFilter = 'all';
  String _priorityFilter = 'all';

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red.shade100;
      case 'medium':
        return Colors.orange.shade100;
      case 'low':
        return Colors.blue.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'new':
        return Colors.blue;
      case 'contacted':
        return Colors.orange;
      case 'closed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _createLead(String brokerId) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    String priority = 'medium';
    DateTime? followUpDate;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add Lead',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Name is required'
                          : null,
                    ),
                    TextFormField(
                      controller: phoneController,
                      decoration: const InputDecoration(labelText: 'Phone'),
                      keyboardType: TextInputType.phone,
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Phone is required'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: priority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: LeadService.priorities
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setSheetState(() => priority = value ?? 'medium');
                      },
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Follow-up date'),
                      subtitle: Text(
                        followUpDate == null
                            ? 'Optional'
                            : '${followUpDate!.year}-${followUpDate!.month.toString().padLeft(2, '0')}-${followUpDate!.day.toString().padLeft(2, '0')}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.event),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate:
                                DateTime.now().add(const Duration(days: 1)),
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked == null) return;
                          setSheetState(() => followUpDate = picked);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          await LeadService().createManualLead(
                            brokerId: brokerId,
                            name: nameController.text,
                            phone: phoneController.text,
                            priority: priority,
                            followUpDate: followUpDate,
                          );
                          if (!context.mounted) return;
                          Navigator.pop(context, true);
                        },
                        child: const Text('Create Lead'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lead created')),
      );
    }
  }

  Future<void> _updateStatus(String leadId, String status) async {
    setState(() => _updatingLeadId = leadId);
    try {
      await LeadService().updateStatus(leadId, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to $status')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    } finally {
      if (mounted) setState(() => _updatingLeadId = null);
    }
  }

  Future<void> _updatePriority(String leadId, String priority) async {
    setState(() => _updatingLeadId = leadId);
    try {
      await LeadService().updatePriority(leadId, priority);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Priority set to ${priority.toUpperCase()}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update priority: $e')),
      );
    } finally {
      if (mounted) setState(() => _updatingLeadId = null);
    }
  }

  Future<void> _setFollowUp(String leadId) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 2)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;

    setState(() => _updatingLeadId = leadId);
    try {
      await LeadService().setFollowUp(leadId, picked);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Follow-up date updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to set follow-up: $e')),
      );
    } finally {
      if (mounted) setState(() => _updatingLeadId = null);
    }
  }

  Future<void> _addNote(String leadId) async {
    final noteController = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add note'),
        content: TextField(
          controller: noteController,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'Enter note'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (added != true) return;

    setState(() => _updatingLeadId = leadId);
    try {
      await LeadService().addNote(leadId: leadId, note: noteController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note added')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add note: $e')),
      );
    } finally {
      if (mounted) setState(() => _updatingLeadId = null);
    }
  }

  bool _matchesFilters(Map<String, dynamic> data) {
    final status = (data['status'] ?? 'new').toString();
    final priority = (data['priority'] ?? 'medium').toString();

    final statusOk = _statusFilter == 'all' || status == _statusFilter;
    final priorityOk = _priorityFilter == 'all' || priority == _priorityFilter;
    return statusOk && priorityOk;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view leads')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Leads Management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createLead(user.uid),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add Lead'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: LeadService().brokerLeads(user.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Unable to load leads: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final leads = snapshot.data?.docs ?? [];
          final filteredLeads =
              leads.where((doc) => _matchesFilters(doc.data())).toList();
          final now = DateTime.now();
          final reminders = filteredLeads.where((doc) {
            final data = doc.data();
            final status = (data['status'] ?? '').toString();
            final followUp = (data['followUpDate'] as Timestamp?)?.toDate();
            if (followUp == null || status == 'closed') return false;
            return !followUp.isAfter(DateTime(now.year, now.month, now.day));
          }).toList();

          if (leads.isEmpty) {
            return const Center(child: Text('No leads yet'));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _statusFilter,
                        decoration: const InputDecoration(labelText: 'Status filter'),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All statuses')),
                          DropdownMenuItem(value: 'new', child: Text('New')),
                          DropdownMenuItem(value: 'contacted', child: Text('Contacted')),
                          DropdownMenuItem(value: 'closed', child: Text('Closed')),
                        ],
                        onChanged: (value) {
                          setState(() => _statusFilter = value ?? 'all');
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _priorityFilter,
                        decoration: const InputDecoration(labelText: 'Priority filter'),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All priorities')),
                          DropdownMenuItem(value: 'high', child: Text('High')),
                          DropdownMenuItem(value: 'medium', child: Text('Medium')),
                          DropdownMenuItem(value: 'low', child: Text('Low')),
                        ],
                        onChanged: (value) {
                          setState(() => _priorityFilter = value ?? 'all');
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (reminders.isNotEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${reminders.length} lead reminder(s) due for follow-up today or earlier.',
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: filteredLeads.isEmpty
                    ? const Center(child: Text('No leads match the selected filters'))
                    : ListView.builder(
                        itemCount: filteredLeads.length,
                        itemBuilder: (context, index) {
                          final doc = filteredLeads[index];
                          final data = doc.data();
                          final priority = (data['priority'] ?? 'medium').toString();
                          final status = (data['status'] ?? 'new').toString();
                          final followUp =
                              (data['followUpDate'] as Timestamp?)?.toDate();
                          final notes = (data['notes'] as List<dynamic>? ?? [])
                              .cast<Map<String, dynamic>>();
                          final followUpText = followUp == null
                              ? 'Not set'
                              : '${followUp.year}-${followUp.month.toString().padLeft(2, '0')}-${followUp.day.toString().padLeft(2, '0')}';
                          final isUpdating = _updatingLeadId == doc.id;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: ListTile(
                              title: Text(data['name']?.toString() ?? '-'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  Text('Phone: ${data['phone'] ?? '-'}'),
                                  Text(
                                    'Status: ${status.toUpperCase()}',
                                    style: TextStyle(
                                      color: _statusColor(status),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text('Follow-up: $followUpText'),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      Chip(
                                        label: Text('Priority: $priority'),
                                        backgroundColor: _priorityColor(priority),
                                      ),
                                      Chip(
                                        label: Text('Notes: ${notes.length}'),
                                        avatar: const Icon(Icons.note, size: 16),
                                      ),
                                    ],
                                  ),
                                  if (notes.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Last note: ${notes.last['text'] ?? ''}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                              trailing: isUpdating
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : PopupMenuButton<String>(
                                      onSelected: (value) async {
                                        if (value.startsWith('status:')) {
                                          await _updateStatus(
                                            doc.id,
                                            value.replaceFirst('status:', ''),
                                          );
                                        } else if (value.startsWith('priority:')) {
                                          await _updatePriority(
                                            doc.id,
                                            value.replaceFirst('priority:', ''),
                                          );
                                        } else if (value == 'follow_up') {
                                          await _setFollowUp(doc.id);
                                        } else if (value == 'note') {
                                          await _addNote(doc.id);
                                        }
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                          value: 'status:new',
                                          child: Text('Status: New'),
                                        ),
                                        PopupMenuItem(
                                          value: 'status:contacted',
                                          child: Text('Status: Contacted'),
                                        ),
                                        PopupMenuItem(
                                          value: 'status:closed',
                                          child: Text('Status: Closed'),
                                        ),
                                        PopupMenuDivider(),
                                        PopupMenuItem(
                                          value: 'priority:high',
                                          child: Text('Priority: High'),
                                        ),
                                        PopupMenuItem(
                                          value: 'priority:medium',
                                          child: Text('Priority: Medium'),
                                        ),
                                        PopupMenuItem(
                                          value: 'priority:low',
                                          child: Text('Priority: Low'),
                                        ),
                                        PopupMenuDivider(),
                                        PopupMenuItem(
                                          value: 'follow_up',
                                          child: Text('Set Follow-up Date'),
                                        ),
                                        PopupMenuItem(
                                          value: 'note',
                                          child: Text('Add Note'),
                                        ),
                                      ],
                                    ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
