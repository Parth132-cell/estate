import 'package:flutter/material.dart';

class ArPreviewScreen extends StatelessWidget {
  const ArPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AR Preview')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.view_in_ar_rounded,
                    size: 72, color: Color(0xFF1D4ED8)),
              ),
              const SizedBox(height: 18),
              const Text(
                'AR Preview (Phase 3)',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'This module will render room/property overlays using an AR SDK.\nCurrent screen is a production-safe placeholder route.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('AR engine integration coming soon')),
                  );
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Try Demo Overlay'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
