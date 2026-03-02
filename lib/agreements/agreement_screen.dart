import 'package:flutter/material.dart';
import 'agreement_service.dart';
import 'agreement_pdf_stub.dart';

class AgreementScreen extends StatelessWidget {
  final String agreementId;
  final String status;

  const AgreementScreen({
    super.key,
    required this.agreementId,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Digital Agreement")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Agreement Status: $status"),
            const SizedBox(height: 20),

            ElevatedButton(
              child: const Text("View Agreement"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AgreementPdfStub()),
                );
              },
            ),

            const SizedBox(height: 20),

            if (status == 'draft')
              ElevatedButton(
                child: const Text("Accept Agreement"),
                onPressed: () async {
                  await AgreementService().accept(agreementId);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Agreement accepted")),
                  );

                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }
}
