import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/contact/contact_chat_screen.dart';
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
      case 'negotiation':
        return Colors.deepPurple;
      case 'closed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _createLead(String brokerId) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    // PRIVACY: phone stored internally but never shown in UI
    final phoneController = TextEditingController();
    String priority = 'medium';
    DateTime? followUpDate;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add Lead',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Name required'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    // Phone stored internally for broker's own CRM use
                    // but NEVER displayed in buyer-facing screens
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone (internal use only)',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        helperText: 'Stored privately. Never shown to buyers.',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Phone required'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: priority,
                      decoration: InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: LeadService.priorities
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(
                                item[0].toUpperCase() + item.substring(1),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setSheetState(() => priority = value ?? 'medium'),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_outlined),
                      title: const Text('Follow-up date'),
                      subtitle: Text(
                        followUpDate == null
                            ? 'Optional — tap to set'
                            : '${followUpDate!.day}/${followUpDate!.month}/${followUpDate!.year}',
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(
                            const Duration(days: 1),
                          ),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) {
                          setSheetState(() => followUpDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
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
                        child: const Text(
                          'Create Lead',
                          style: TextStyle(fontSize: 15),
                        ),
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
        const SnackBar(
          content: Text('Lead created'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _updateStatus(String leadId, String status) async {
    setState(() => _updatingLeadId = leadId);
    try {
      await LeadService().updateStatus(leadId, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status → ${status.toUpperCase()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
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
        SnackBar(
          content: Text('Priority → ${priority.toUpperCase()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
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
        const SnackBar(
          content: Text('Follow-up date updated'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
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
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'What did you discuss?',
            border: OutlineInputBorder(),
          ),
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
        const SnackBar(
          content: Text('Note added'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _updatingLeadId = null);
    }
    noteController.dispose();
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
          final filtered = leads
              .where((doc) => _matchesFilters(doc.data()))
              .toList();
          final now = DateTime.now();
          final reminders = filtered.where((doc) {
            final data = doc.data();
            final status = (data['status'] ?? '').toString();
            final followUp = (data['followUpDate'] as Timestamp?)?.toDate();
            if (followUp == null || status == 'closed') return false;
            return !followUp.isAfter(DateTime(now.year, now.month, now.day));
          }).toList();

          if (leads.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No leads yet', style: TextStyle(fontSize: 16)),
                  SizedBox(height: 6),
                  Text(
                    'Tap + Add Lead to get started',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Filters
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _statusFilter,
                        isDense: true,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All')),
                          DropdownMenuItem(value: 'new', child: Text('New')),
                          DropdownMenuItem(
                            value: 'contacted',
                            child: Text('Contacted'),
                          ),
                          DropdownMenuItem(
                            value: 'negotiation',
                            child: Text('Negotiation'),
                          ),
                          DropdownMenuItem(
                            value: 'closed',
                            child: Text('Closed'),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _statusFilter = v ?? 'all'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _priorityFilter,
                        isDense: true,
                        decoration: InputDecoration(
                          labelText: 'Priority',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All')),
                          DropdownMenuItem(value: 'high', child: Text('High')),
                          DropdownMenuItem(
                            value: 'medium',
                            child: Text('Medium'),
                          ),
                          DropdownMenuItem(value: 'low', child: Text('Low')),
                        ],
                        onChanged: (v) =>
                            setState(() => _priorityFilter = v ?? 'all'),
                      ),
                    ),
                  ],
                ),
              ),

              // Reminder banner
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
                      const Icon(
                        Icons.notifications_active,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${reminders.length} follow-up(s) due today or overdue',
                        ),
                      ),
                    ],
                  ),
                ),

              // List
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No leads match filters'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final doc = filtered[index];
                          final data = doc.data();
                          final priority = (data['priority'] ?? 'medium')
                              .toString();
                          final status = (data['status'] ?? 'new').toString();
                          final followUp = (data['followUpDate'] as Timestamp?)
                              ?.toDate();
                          final notes = (data['notes'] as List? ?? [])
                              .cast<Map<String, dynamic>>();
                          final isUpdating = _updatingLeadId == doc.id;
                          final propertyId =
                              data['propertyId']?.toString() ?? '';
                          final propertyTitle =
                              data['propertyTitle']?.toString() ?? '';
                          final name = (data['name'] ?? 'Unknown').toString();

                          // Format follow-up date
                          final followUpText = followUp == null
                              ? 'Not set'
                              : '${followUp.day}/${followUp.month}/${followUp.year}';

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _priorityColor(priority),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      priority.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  // PRIVACY: Show masked alias if available, never raw phone
                                  if ((data['maskedPhoneAlias'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.phone_outlined,
                                          size: 14,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Masked: ${data['maskedPhoneAlias']}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    )
                                  else
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.lock_outline,
                                          size: 14,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'Contact via EstateX chat',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: _statusColor(status),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        status[0].toUpperCase() +
                                            status.substring(1),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _statusColor(status),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Icon(
                                        Icons.event_outlined,
                                        size: 12,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        followUpText,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (notes.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '📝 ${notes.last['text'] ?? ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
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
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Chat button — uses our new ContactChatScreen
                                        IconButton(
                                          tooltip: 'Open chat',
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ContactChatScreen(
                                                brokerId: doc.id,
                                                propertyId: propertyId,
                                                propertyTitle:
                                                    propertyTitle.isNotEmpty
                                                    ? propertyTitle
                                                    : 'Lead: $name',
                                              ),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.chat_bubble_outline,
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          onSelected: (value) async {
                                            if (value.startsWith('status:')) {
                                              await _updateStatus(
                                                doc.id,
                                                value.replaceFirst(
                                                  'status:',
                                                  '',
                                                ),
                                              );
                                            } else if (value.startsWith(
                                              'priority:',
                                            )) {
                                              await _updatePriority(
                                                doc.id,
                                                value.replaceFirst(
                                                  'priority:',
                                                  '',
                                                ),
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
                                              value: 'status:negotiation',
                                              child: Text(
                                                'Status: Negotiation',
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'status:closed',
                                              child: Text('Status: Closed'),
                                            ),
                                            PopupMenuDivider(),
                                            PopupMenuItem(
                                              value: 'priority:high',
                                              child: Text('🔴 High priority'),
                                            ),
                                            PopupMenuItem(
                                              value: 'priority:medium',
                                              child: Text('🟡 Medium priority'),
                                            ),
                                            PopupMenuItem(
                                              value: 'priority:low',
                                              child: Text('🔵 Low priority'),
                                            ),
                                            PopupMenuDivider(),
                                            PopupMenuItem(
                                              value: 'follow_up',
                                              child: Text('Set Follow-up'),
                                            ),
                                            PopupMenuItem(
                                              value: 'note',
                                              child: Text('Add Note'),
                                            ),
                                          ],
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
