import 'package:flutter/material.dart';

class AgreementPdfStub extends StatelessWidget {
  final String documentBody;

  const AgreementPdfStub({super.key, required this.documentBody});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Agreement Document")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Text(documentBody, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}
