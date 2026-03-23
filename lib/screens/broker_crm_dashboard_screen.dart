import 'package:estatex_app/services/broker_crm_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BrokerCrmDashboardScreen extends StatelessWidget {
  const BrokerCrmDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view CRM dashboard')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Lead Analytics Dashboard')),
      body: StreamBuilder<Map<String, int>>(
        stream: BrokerCrmService().brokerKpis(user.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Unable to load CRM data: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final kpi = snapshot.data ?? const <String, int>{};
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionTitle('Lead Funnel'),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _KpiCard('Total Leads', kpi['totalLeads'] ?? 0, Icons.people),
                  _KpiCard('New Leads', kpi['newLeads'] ?? 0, Icons.fiber_new),
                  _KpiCard('Contacted', kpi['contacted'] ?? 0, Icons.call),
                  _KpiCard('Closed', kpi['closed'] ?? 0, Icons.check_circle_outline),
                  _KpiCard('High Priority', kpi['highPriority'] ?? 0, Icons.priority_high),
                  _KpiCard('Medium Priority', kpi['mediumPriority'] ?? 0, Icons.drag_handle),
                  _KpiCard('Low Priority', kpi['lowPriority'] ?? 0, Icons.low_priority),
                  _KpiCard('Leads with Notes', kpi['leadsWithNotes'] ?? 0, Icons.sticky_note_2_outlined),
                  _KpiCard('Reminders Due', kpi['remindersDue'] ?? 0, Icons.notifications_active_outlined),
                  _KpiCard('Contact Rate', kpi['contactedRate'] ?? 0, Icons.percent, suffix: '%'),
                  _KpiCard('Close Rate', kpi['closeRate'] ?? 0, Icons.trending_up, suffix: '%'),
                ],
              ),
              const SizedBox(height: 20),
              _SectionTitle('Deal Funnel'),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _KpiCard('Active Deals', kpi['activeDeals'] ?? 0, Icons.handshake_outlined),
                  _KpiCard('Won Deals', kpi['wonDeals'] ?? 0, Icons.emoji_events_outlined),
                  _KpiCard('Rejected Deals', kpi['rejectedDeals'] ?? 0, Icons.cancel_outlined),
                  _KpiCard('Win Rate', kpi['winRate'] ?? 0, Icons.trending_up, suffix: '%'),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final String suffix;

  const _KpiCard(this.title, this.value, this.icon, {this.suffix = ''});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF1D4ED8)),
            const Spacer(),
            Text(
              '$value$suffix',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            Text(title, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
