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
      appBar: AppBar(title: const Text('Broker CRM Dashboard')),
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
          return GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.all(16),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _KpiCard('Total Leads', kpi['totalLeads'] ?? 0, Icons.people),
              _KpiCard('Hot Leads', kpi['hotLeads'] ?? 0, Icons.local_fire_department),
              _KpiCard('Contacted', kpi['contacted'] ?? 0, Icons.call),
              _KpiCard('Active Deals', kpi['activeDeals'] ?? 0, Icons.handshake_outlined),
              _KpiCard('Won Deals', kpi['wonDeals'] ?? 0, Icons.emoji_events_outlined),
            ],
          );
        },
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;

  const _KpiCard(this.title, this.value, this.icon);

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
            Text('$value', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
