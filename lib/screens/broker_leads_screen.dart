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

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'hot':
        return Colors.red;
      case 'warm':
        return Colors.orange;
      case 'cold':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Future<void> _markContacted(String leadId) async {
    setState(() => _updatingLeadId = leadId);
    try {
      await LeadService().markContacted(leadId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lead marked as contacted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update lead: $e')),
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view leads')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Leads')),
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
          if (leads.isEmpty) {
            return const Center(child: Text('No leads yet'));
          }

          return ListView.builder(
            itemCount: leads.length,
            itemBuilder: (context, index) {
              final doc = leads[index];
              final data = doc.data();
              final priority = (data['priority'] ?? 'warm').toString();
              final followUp = (data['nextFollowUp'] as Timestamp?)?.toDate();
              final followUpText = followUp == null
                  ? 'Not set'
                  : '${followUp.year}-${followUp.month.toString().padLeft(2, '0')}-${followUp.day.toString().padLeft(2, '0')}';
              final isUpdating = _updatingLeadId == doc.id;

              return ListTile(
                title: Text('Property: ${data['propertyId'] ?? '-'}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status: ${data['status'] ?? 'new'}'),
                    Text('Next follow-up: $followUpText'),
                    Row(
                      children: [
                        const Text('Priority: '),
                        Chip(
                          label: Text(priority),
                          backgroundColor: _priorityColor(priority),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: isUpdating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'contacted') {
                            await _markContacted(doc.id);
                          } else if (value == 'hot' || value == 'warm' || value == 'cold') {
                            await _updatePriority(doc.id, value);
                          } else if (value == 'follow_up') {
                            await _setFollowUp(doc.id);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'contacted', child: Text('Mark Contacted')),
                          PopupMenuItem(value: 'follow_up', child: Text('Set Follow-up')),
                          PopupMenuDivider(),
                          PopupMenuItem(value: 'hot', child: Text('Hot')),
                          PopupMenuItem(value: 'warm', child: Text('Warm')),
                          PopupMenuItem(value: 'cold', child: Text('Cold')),
                        ],
                      ),
              );
            },
          );
        },
      ),
    );
  }
}
