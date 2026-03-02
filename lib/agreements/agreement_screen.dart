import 'package:flutter/material.dart';

import 'agreement_pdf_stub.dart';
import 'agreement_service.dart';

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
      body: FutureBuilder(
        future: AgreementService().getById(agreementId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() ?? <String, dynamic>{};
          final agreementStatus = (data['status'] ?? status).toString();
          final esignStatus = (data['esignStatus'] ?? 'not_sent').toString();
          final docBody = (data['documentBody'] ?? 'No agreement body found')
              .toString();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Agreement Status: $agreementStatus"),
                const SizedBox(height: 8),
                Text("eSign Status: $esignStatus"),
                const SizedBox(height: 20),

                ElevatedButton(
                  child: const Text("View Agreement"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AgreementPdfStub(documentBody: docBody),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                if (agreementStatus == 'draft')
                  ElevatedButton(
                    child: const Text("Accept Agreement"),
                    onPressed: () async {
                      await AgreementService().accept(agreementId);

                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Agreement accepted")),
                      );
                    },
                  ),

                const SizedBox(height: 10),

                if (esignStatus == 'not_sent')
                  OutlinedButton(
                    child: const Text("Send for eSign"),
                    onPressed: () async {
                      await AgreementService().sendForEsign(agreementId);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Agreement sent for eSign"),
                        ),
                      );
                    },
                  ),

                if (esignStatus == 'sent')
                  OutlinedButton(
                    child: const Text("Mark eSign Completed"),
                    onPressed: () async {
                      await AgreementService().markEsignCompleted(agreementId);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("eSign marked completed")),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
