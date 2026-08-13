import 'package:estatex_app/broker_crm/broker_crm_models.dart';
import 'package:estatex_app/colors.dart';
import 'package:estatex_app/services/broker_crm_service.dart';
import 'package:estatex_app/services/lead_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BrokerCrmDashboardScreen extends StatefulWidget {
  const BrokerCrmDashboardScreen({super.key});

  @override
  State<BrokerCrmDashboardScreen> createState() =>
      _BrokerCrmDashboardScreenState();
}

class _BrokerCrmDashboardScreenState extends State<BrokerCrmDashboardScreen> {
  final _crmService = BrokerCrmService();
  String? _busyLeadId;

  Future<void> _createLead(String brokerId) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final messageController = TextEditingController();
    String priority = LeadPriority.medium.key;
    DateTime? followUpDate;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create lead',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Lead name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Lead name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Phone number is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: messageController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Lead context',
                        hintText: 'Budget, location, property preference...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: priority,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(),
                      ),
                      items: LeadService.priorities
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item.toUpperCase()),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setSheetState(
                          () => priority = value ?? LeadPriority.medium.key,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.alarm_outlined),
                      title: const Text('First reminder'),
                      subtitle: Text(
                        followUpDate == null
                            ? 'Add a follow-up date'
                            : _formatDate(followUpDate),
                      ),
                      trailing: TextButton(
                        onPressed: () async {
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
                          if (picked == null) return;
                          setSheetState(() => followUpDate = picked);
                        },
                        child: const Text('Pick'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;

                          await LeadService().createManualLead(
                            brokerId: brokerId,
                            name: nameController.text,
                            phone: phoneController.text,
                            priority: priority,
                            message: messageController.text,
                            followUpDate: followUpDate,
                          );

                          if (!context.mounted) return;
                          Navigator.pop(context, true);
                        },
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Save lead'),
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

    nameController.dispose();
    phoneController.dispose();
    messageController.dispose();

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lead added to the pipeline')),
      );
    }
  }

  Future<void> _moveLead(BrokerCrmLead lead, LeadStage stage) async {
    setState(() => _busyLeadId = lead.id);
    try {
      await _crmService.moveLeadToStage(leadId: lead.id, stage: stage);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${lead.name} moved to ${stage.label}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to update stage: $e')));
    } finally {
      if (mounted) {
        setState(() => _busyLeadId = null);
      }
    }
  }

  Future<void> _addNote(BrokerCrmLead lead) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final noteController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add note for ${lead.name}'),
          content: TextField(
            controller: noteController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Capture the conversation, objections, or next steps',
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
              child: const Text('Save note'),
            ),
          ],
        );
      },
    );

    if (saved != true) {
      noteController.dispose();
      return;
    }

    setState(() => _busyLeadId = lead.id);
    try {
      await _crmService.addLeadNote(
        leadId: lead.id,
        note: noteController.text,
        userId: user.uid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Note saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to save note: $e')));
    } finally {
      noteController.dispose();
      if (mounted) {
        setState(() => _busyLeadId = null);
      }
    }
  }

  Future<void> _scheduleReminder(BrokerCrmLead lead) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: lead.followUpDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;

    setState(() => _busyLeadId = lead.id);
    try {
      await _crmService.scheduleReminder(leadId: lead.id, reminderAt: picked);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reminder scheduled for ${lead.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to schedule reminder: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyLeadId = null);
      }
    }
  }

  List<BrokerCrmLead> _leadsForStage(
    List<BrokerCrmLead> leads,
    LeadStage stage,
  ) {
    return leads.where((lead) => lead.status == stage).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view CRM dashboard')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Broker CRM'),
        actions: [
          IconButton(
            tooltip: 'Add lead',
            onPressed: () => _createLead(user.uid),
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      body: StreamBuilder<BrokerCrmDashboardData>(
        stream: _crmService.watchDashboard(user.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Unable to load CRM data: ${snapshot.error}'),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final dashboard = snapshot.data;
          if (dashboard == null) {
            return const Center(child: Text('No CRM data available'));
          }

          final analytics = dashboard.analytics;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _DashboardHero(analytics: analytics),
              const SizedBox(height: 18),
              const _SectionHeading(
                title: 'Analytics',
                subtitle:
                    'Conversion health, activity coverage, and deal momentum.',
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 560;
                  final cardWidth = isNarrow
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 12) / 2;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _MetricCard(
                          title: 'Total leads',
                          value: analytics.totalLeads.toString(),
                          caption: 'All broker opportunities',
                          icon: Icons.people_alt_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _MetricCard(
                          title: 'Contact rate',
                          value: '${analytics.contactRate}%',
                          caption: 'Leads beyond new stage',
                          icon: Icons.call_outlined,
                          color: const Color(0xFF0F766E),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _MetricCard(
                          title: 'Negotiation rate',
                          value: '${analytics.negotiationRate}%',
                          caption: 'Opportunities in active discussion',
                          icon: Icons.balance_outlined,
                          color: const Color(0xFF7C3AED),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _MetricCard(
                          title: 'Close rate',
                          value: '${analytics.closeRate}%',
                          caption: 'Pipeline to closed conversion',
                          icon: Icons.check_circle_outline,
                          color: AppColors.success,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _MetricCard(
                          title: 'Notes coverage',
                          value: '${analytics.leadsWithNotes}',
                          caption:
                              '${analytics.totalNotes} notes across tracked leads',
                          icon: Icons.sticky_note_2_outlined,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _MetricCard(
                          title: 'Deal win rate',
                          value: '${analytics.winRate}%',
                          caption:
                              '${analytics.wonDeals} won / ${analytics.activeDeals + analytics.wonDeals + analytics.rejectedDeals} total deals',
                          icon: Icons.emoji_events_outlined,
                          color: const Color(0xFFBE185D),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pipeline conversion',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final stage in LeadStage.values) ...[
                      _StageProgressBar(
                        label: stage.label,
                        value: analytics.countFor(stage),
                        total: analytics.totalLeads,
                        color: _stageColor(stage),
                      ),
                      if (stage != LeadStage.closed) const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionHeading(
                title: 'Lead pipeline',
                subtitle:
                    'Move leads across stages and keep follow-ups visible.',
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final stage in LeadStage.values)
                      Padding(
                        padding: EdgeInsets.only(
                          right: stage == LeadStage.closed ? 0 : 12,
                        ),
                        child: _PipelineColumn(
                          stage: stage,
                          leads: _leadsForStage(dashboard.leads, stage),
                          totalLeads: analytics.totalLeads,
                          busyLeadId: _busyLeadId,
                          onMove: _moveLead,
                          onAddNote: _addNote,
                          onScheduleReminder: _scheduleReminder,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionHeading(
                title: 'Notes and reminders',
                subtitle:
                    'Today\'s follow-ups and the latest context from the team.',
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 760;
                  if (isCompact) {
                    return Column(
                      children: [
                        _ReminderPanel(
                          reminders: dashboard.reminders,
                          leads: dashboard.leads,
                          onScheduleReminder: _scheduleReminder,
                        ),
                        const SizedBox(height: 12),
                        _RecentNotesPanel(notes: dashboard.recentNotes),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _ReminderPanel(
                          reminders: dashboard.reminders,
                          leads: dashboard.leads,
                          onScheduleReminder: _scheduleReminder,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RecentNotesPanel(notes: dashboard.recentNotes),
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({required this.analytics});

  final BrokerAnalyticsSnapshot analytics;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F3D91), Color(0xFF2563EB), Color(0xFF38BDF8)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Broker workspace',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Stay on top of leads, protect follow-ups, and push negotiations forward.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  label: 'Reminders due',
                  value: analytics.remindersDue.toString(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeroStat(
                  label: 'Upcoming in 3 days',
                  value: analytics.upcomingReminders.toString(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeroStat(
                  label: 'Won deals',
                  value: analytics.wonDeals.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StageProgressBar extends StatelessWidget {
  const _StageProgressBar({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : value / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '$value / $total',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: ratio.clamp(0.0, 1.0),
            color: color,
            backgroundColor: color.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}

class _PipelineColumn extends StatelessWidget {
  const _PipelineColumn({
    required this.stage,
    required this.leads,
    required this.totalLeads,
    required this.busyLeadId,
    required this.onMove,
    required this.onAddNote,
    required this.onScheduleReminder,
  });

  final LeadStage stage;
  final List<BrokerCrmLead> leads;
  final int totalLeads;
  final String? busyLeadId;
  final Future<void> Function(BrokerCrmLead lead, LeadStage stage) onMove;
  final Future<void> Function(BrokerCrmLead lead) onAddNote;
  final Future<void> Function(BrokerCrmLead lead) onScheduleReminder;

  @override
  Widget build(BuildContext context) {
    final color = _stageColor(stage);
    final ratio = totalLeads == 0
        ? 0
        : ((leads.length * 100) / totalLeads).round();
    final visibleLeads = leads.take(4).toList();

    return Container(
      width: 292,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stage.label,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$ratio% of pipeline',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${leads.length}',
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (leads.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'No leads in this stage yet.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            for (final lead in visibleLeads) ...[
              _LeadCard(
                lead: lead,
                busy: busyLeadId == lead.id,
                onMove: onMove,
                onAddNote: onAddNote,
                onScheduleReminder: onScheduleReminder,
              ),
              if (lead != visibleLeads.last) const SizedBox(height: 10),
            ],
          if (leads.length > 4) ...[
            const SizedBox(height: 10),
            Text(
              '+${leads.length - 4} more leads in ${stage.label.toLowerCase()}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LeadCard extends StatelessWidget {
  const _LeadCard({
    required this.lead,
    required this.busy,
    required this.onMove,
    required this.onAddNote,
    required this.onScheduleReminder,
  });

  final BrokerCrmLead lead;
  final bool busy;
  final Future<void> Function(BrokerCrmLead lead, LeadStage stage) onMove;
  final Future<void> Function(BrokerCrmLead lead) onAddNote;
  final Future<void> Function(BrokerCrmLead lead) onScheduleReminder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lead.phone.isEmpty ? 'No phone saved' : lead.phone,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  onSelected: (value) async {
                    if (value.startsWith('move:')) {
                      final rawStage = value.replaceFirst('move:', '');
                      await onMove(lead, LeadStage.fromRaw(rawStage));
                    } else if (value == 'note') {
                      await onAddNote(lead);
                    } else if (value == 'reminder') {
                      await onScheduleReminder(lead);
                    }
                  },
                  itemBuilder: (context) => [
                    for (final stage in LeadStage.values)
                      if (stage != lead.status)
                        PopupMenuItem(
                          value: 'move:${stage.key}',
                          child: Text('Move to ${stage.label}'),
                        ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'note', child: Text('Add note')),
                    const PopupMenuItem(
                      value: 'reminder',
                      child: Text('Schedule reminder'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Badge(
                label: lead.priority.label,
                background: _priorityColor(
                  lead.priority,
                ).withValues(alpha: 0.14),
                foreground: _priorityColor(lead.priority),
              ),
              _Badge(
                label: '${lead.notes.length} notes',
                background: const Color(0xFFE0E7FF),
                foreground: const Color(0xFF4338CA),
              ),
            ],
          ),
          if (lead.followUpDate != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.alarm_outlined,
                  size: 16,
                  color: _isReminderOverdue(lead.followUpDate!)
                      ? AppColors.danger
                      : AppColors.warning,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _reminderLabel(lead.followUpDate!),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (lead.message.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              lead.message.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          if (lead.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Latest note: ${lead.notes.last.text}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReminderPanel extends StatelessWidget {
  const _ReminderPanel({
    required this.reminders,
    required this.leads,
    required this.onScheduleReminder,
  });

  final List<BrokerLeadReminder> reminders;
  final List<BrokerCrmLead> leads;
  final Future<void> Function(BrokerCrmLead lead) onScheduleReminder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Follow-up queue',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Overdue and upcoming reminders pulled from lead records.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          if (reminders.isEmpty)
            const Text(
              'No reminders due right now.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            for (final reminder in reminders) ...[
              _ReminderTile(
                reminder: reminder,
                onTap: () async {
                  final lead = leads
                      .where((item) => item.id == reminder.leadId)
                      .firstOrNull;
                  if (lead == null) return;
                  await onScheduleReminder(lead);
                },
              ),
              if (reminder != reminders.last) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({required this.reminder, required this.onTap});

  final BrokerLeadReminder reminder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = reminder.isOverdue ? AppColors.danger : AppColors.warning;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.leadName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${reminder.stage.label} | ${reminder.priority.label} priority',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _reminderLabel(reminder.dueAt),
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentNotesPanel extends StatelessWidget {
  const _RecentNotesPanel({required this.notes});

  final List<BrokerRecentNote> notes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent notes',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'The latest context captured on active opportunities.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          if (notes.isEmpty)
            const Text(
              'No notes captured yet.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            for (final item in notes) ...[
              _RecentNoteTile(item: item),
              if (item != notes.last) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _RecentNoteTile extends StatelessWidget {
  const _RecentNoteTile({required this.item});

  final BrokerRecentNote item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.leadName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                item.stage.label,
                style: TextStyle(
                  fontSize: 12,
                  color: _stageColor(item.stage),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.note.text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textPrimary, height: 1.45),
          ),
          const SizedBox(height: 8),
          Text(
            item.note.createdAt == null
                ? 'Saved recently'
                : _formatDateTime(item.note.createdAt!),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

Color _stageColor(LeadStage stage) {
  switch (stage) {
    case LeadStage.newLead:
      return const Color(0xFF2563EB);
    case LeadStage.contacted:
      return const Color(0xFF0F766E);
    case LeadStage.negotiation:
      return const Color(0xFF7C3AED);
    case LeadStage.closed:
      return const Color(0xFF16A34A);
  }
}

Color _priorityColor(LeadPriority priority) {
  switch (priority) {
    case LeadPriority.low:
      return const Color(0xFF2563EB);
    case LeadPriority.medium:
      return const Color(0xFFF59E0B);
    case LeadPriority.high:
      return const Color(0xFFDC2626);
  }
}

String _formatDate(DateTime? date) {
  if (date == null) return 'Not set';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _formatDateTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final meridiem = date.hour >= 12 ? 'PM' : 'AM';
  return '${_formatDate(date)} | $hour:$minute $meridiem';
}

String _reminderLabel(DateTime date) {
  final today = DateTime.now();
  final todayOnly = DateTime(today.year, today.month, today.day);
  final dueOnly = DateTime(date.year, date.month, date.day);
  final difference = dueOnly.difference(todayOnly).inDays;

  if (difference == 0) {
    return 'Due today';
  }
  if (difference == -1) {
    return '1 day overdue';
  }
  if (difference < 0) {
    return '${difference.abs()} days overdue';
  }
  if (difference == 1) {
    return 'Due tomorrow';
  }
  return 'Due in $difference days';
}

bool _isReminderOverdue(DateTime date) {
  final today = DateTime.now();
  final todayOnly = DateTime(today.year, today.month, today.day);
  final dueOnly = DateTime(date.year, date.month, date.day);
  return dueOnly.isBefore(todayOnly);
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
