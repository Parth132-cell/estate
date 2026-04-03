import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'agreement_pdf_stub.dart';
import 'agreement_service.dart';

class AgreementScreen extends StatefulWidget {
  final String? agreementId;
  final String? status;

  const AgreementScreen({
    super.key,
    this.agreementId,
    this.status,
  });

  @override
  State<AgreementScreen> createState() => _AgreementScreenState();
}

class _AgreementScreenState extends State<AgreementScreen> {
  final _dealController = TextEditingController();
  final _buyerController = TextEditingController();
  final _sellerController = TextEditingController();
  final _service = AgreementService();

  String? _agreementId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _agreementId = widget.agreementId;
  }

  @override
  void dispose() {
    _dealController.dispose();
    _buyerController.dispose();
    _sellerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final agreementId = _agreementId;

    return Scaffold(
      appBar: AppBar(title: const Text('Buyer-Seller Agreement')),
      body: agreementId == null
          ? _buildCreateForm()
          : FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: _service.getById(agreementId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data?.data() ?? <String, dynamic>{};
                final agreementStatus =
                    (data['status'] ?? widget.status ?? 'draft').toString();
                final esignStatus =
                    (data['esignStatus'] ?? 'not_sent').toString();
                final docBody =
                    (data['documentBody'] ?? 'No agreement body found').toString();
                final pdfUrl = data['pdfUrl']?.toString();

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    children: [
                      Text('Agreement Status: $agreementStatus'),
                      const SizedBox(height: 8),
                      Text('eSign Status: $esignStatus'),
                      const SizedBox(height: 8),
                      if (pdfUrl != null && pdfUrl.isNotEmpty)
                        Text(
                          'PDF: uploaded',
                          style: TextStyle(color: Colors.green.shade700),
                        )
                      else
                        const Text('PDF: not generated'),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        child: const Text('View Agreement Content'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AgreementPdfStub(
                                documentBody: docBody,
                                pdfUrl: pdfUrl,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        child: const Text('Generate PDF + Upload'),
                        onPressed: () => _runAction(
                          () => _service.generatePdfAndUpload(agreementId),
                          successMessage: 'PDF generated and uploaded',
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (agreementStatus == 'draft') ...[
                        ElevatedButton(
                          child: const Text('Accept Agreement'),
                          onPressed: () => _runAction(
                            () => _service.accept(agreementId),
                            successMessage: 'Agreement accepted',
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          child: const Text('Reject Agreement'),
                          onPressed: () => _runAction(
                            () => _service.reject(agreementId),
                            successMessage: 'Agreement rejected',
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (esignStatus == 'not_sent')
                        OutlinedButton(
                          child: const Text('Send for Digital Signature'),
                          onPressed: () => _runAction(
                            () => _service.sendForEsign(agreementId),
                            successMessage: 'Agreement sent for signature',
                          ),
                        ),
                      if (esignStatus == 'pending_buyer')
                        OutlinedButton(
                          child: const Text('Mark Buyer Signed'),
                          onPressed: () => _runAction(
                            () => _service.markBuyerSigned(agreementId),
                            successMessage: 'Buyer signature captured',
                          ),
                        ),
                      if (esignStatus == 'pending_seller')
                        OutlinedButton(
                          child: const Text('Mark Seller Signed'),
                          onPressed: () => _runAction(
                            () => _service.markSellerSigned(agreementId),
                            successMessage: 'Seller signature captured',
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildCreateForm() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          const Text(
            'Create Agreement',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dealController,
            decoration: const InputDecoration(labelText: 'Deal ID'),
          ),
          TextField(
            controller: _buyerController,
            decoration: const InputDecoration(labelText: 'Buyer ID'),
          ),
          TextField(
            controller: _sellerController,
            decoration: const InputDecoration(labelText: 'Seller ID'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _submitting ? null : _createAgreement,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create Buyer-Seller Agreement'),
          ),
        ],
      ),
    );
  }

  Future<void> _createAgreement() async {
    if (_dealController.text.isEmpty ||
        _buyerController.text.isEmpty ||
        _sellerController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final id = await _service.createAgreement(
        dealId: _dealController.text.trim(),
        buyerId: _buyerController.text.trim(),
        sellerId: _sellerController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _agreementId = id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agreement created successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create agreement: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _runAction(
    Future<dynamic> Function() action, {
    required String successMessage,
  }) async {
    try {
      await action();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Action failed: $e')));
    }
  }
}
