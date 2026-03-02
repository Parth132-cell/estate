import 'package:flutter/material.dart';

class AgreementPdfStub extends StatelessWidget {
  const AgreementPdfStub({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Agreement Document")),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          "This is a system-generated agreement document.\n\n"
          "In Phase-2, this will be a legally binding PDF "
          "with digital signatures (e-Sign).",
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
