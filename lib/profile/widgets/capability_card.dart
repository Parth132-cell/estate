import 'package:flutter/material.dart';

class CapabilityTile extends StatelessWidget {
  final String title;
  final bool enabled;
  final VoidCallback? onUnlock;

  const CapabilityTile({
    super.key,
    required this.title,
    required this.enabled,
    this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        enabled ? Icons.lock_open : Icons.lock,
        color: enabled ? Colors.green : Colors.grey,
      ),
      title: Text(title),
      subtitle: Text(
        enabled ? 'Enabled' : 'Locked',
        style: TextStyle(color: enabled ? Colors.green : Colors.grey),
      ),
      trailing: !enabled
          ? TextButton(onPressed: onUnlock, child: const Text('Unlock'))
          : null,
    );
  }
}
