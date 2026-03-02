import 'package:flutter/material.dart';

class PropertyTypeSelector extends StatelessWidget {
  final String selected; // individual | professional
  final ValueChanged<String> onSelect;

  const PropertyTypeSelector({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Listing Type',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            _OptionCard(
              label: 'Owner',
              subtitle: 'List your own property',
              icon: Icons.person,
              selected: selected == 'individual',
              onTap: () => onSelect('individual'),
            ),
            const SizedBox(width: 12),
            _OptionCard(
              label: 'Professional',
              subtitle: 'Broker / Agent listing',
              icon: Icons.business,
              selected: selected == 'professional',
              onTap: () => onSelect('professional'),
            ),
          ],
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? Colors.blue : Colors.grey.shade300;
    final bgColor = selected ? Colors.blue.withOpacity(0.08) : Colors.white;
    final iconColor = selected ? Colors.blue : Colors.grey;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
