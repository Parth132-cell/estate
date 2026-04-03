import 'package:flutter/material.dart';

class AgreementPdfStub extends StatelessWidget {
  final String documentBody;
  final String? pdfUrl;

  const AgreementPdfStub({
    super.key,
    required this.documentBody,
    this.pdfUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agreement Document')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pdfUrl != null && pdfUrl!.isNotEmpty)
                SelectableText('PDF URL: $pdfUrl')
              else
                const Text('PDF not generated yet.'),
              const SizedBox(height: 16),
              const Text(
                'Agreement Body',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(documentBody, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
