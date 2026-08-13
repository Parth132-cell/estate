import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('agreements')
                  .doc(agreementId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data?.data() ?? <String, dynamic>{};
                final agreementStatus =
                    (data['status'] ?? widget.status ?? 'draft').toString();
                final esignStatus =
                    (data['esignStatus'] ?? 'not_sent').toString();
                final envelopeStatus =
                    (data['envelopeStatus'] ?? 'not_started').toString();
                final docBody =
                    (data['documentBody'] ?? 'No agreement body found').toString();
                final pdfUrl = data['pdfUrl']?.toString();
                final signedPdfUrl = data['signedPdfUrl']?.toString();
                final signerRole = _service.currentSignerRole(data);
                final signers =
                    Map<String, dynamic>.from(data['signers'] as Map? ?? {});
                final buyerSigner =
                    Map<String, dynamic>.from(signers['buyer'] as Map? ?? {});
                final sellerSigner =
                    Map<String, dynamic>.from(signers['seller'] as Map? ?? {});
                final canBuyerSign = signerRole == 'buyer' &&
                    esignStatus == 'pending_buyer';
                final canSellerSign = signerRole == 'seller' &&
                    esignStatus == 'pending_seller';

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    children: [
                      _InfoCard(
                        title: 'Agreement Status',
                        value: agreementStatus,
                      ),
                      const SizedBox(height: 10),
                      _InfoCard(
                        title: 'eSign Status',
                        value: esignStatus,
                      ),
                      const SizedBox(height: 10),
                      _InfoCard(
                        title: 'Envelope Status',
                        value: envelopeStatus,
                      ),
                      const SizedBox(height: 14),
                      _SignerTile(
                        title: 'Buyer Signer',
                        data: buyerSigner,
                      ),
                      const SizedBox(height: 10),
                      _SignerTile(
                        title: 'Seller Signer',
                        data: sellerSigner,
                      ),
                      const SizedBox(height: 18),
                      if (pdfUrl != null && pdfUrl.isNotEmpty)
                        Text(
                          'Draft PDF stored',
                          style: TextStyle(color: Colors.green.shade700),
                        )
                      else
                        const Text('Draft PDF not generated'),
                      if (signedPdfUrl != null && signedPdfUrl.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Signed PDF stored',
                          style: TextStyle(color: Colors.green.shade700),
                        ),
                      ],
                      const SizedBox(height: 20),
                      ElevatedButton(
                        child: const Text('View Agreement Content'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AgreementPdfStub(
                                documentBody: docBody,
                                pdfUrl: signedPdfUrl?.isNotEmpty == true
                                    ? signedPdfUrl
                                    : pdfUrl,
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
                      const SizedBox(height: 10),
                      OutlinedButton(
                        child: const Text('Refresh Signature Status'),
                        onPressed: () => _runAction(
                          () => _service.syncSignatureStatus(agreementId),
                          successMessage: 'Agreement status synced',
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
                      if (agreementStatus == 'accepted' &&
                          esignStatus == 'not_sent')
                        OutlinedButton(
                          child: const Text('Send for Digital Signature'),
                          onPressed: () => _runAction(
                            () => _service.sendForEsign(agreementId),
                            successMessage: 'Agreement sent for signature',
                          ),
                        ),
                      if (canBuyerSign || canSellerSign) ...[
                        const SizedBox(height: 10),
                        ElevatedButton(
                          child: Text(
                            canBuyerSign
                                ? 'Open Buyer Signing Session'
                                : 'Open Seller Signing Session',
                          ),
                          onPressed: () => _openSigningSession(agreementId),
                        ),
                      ],
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

  Future<void> _openSigningSession(String agreementId) async {
    try {
      final signingUrl = await _service.createSigningSession(agreementId);
      final uri = Uri.parse(signingUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open signing session')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open signing session: $e')),
      );
    }
  }

  Future<void> _runAction(
    Future<dynamic> Function() action, {
    required String successMessage,
  }) async {
    try {
      await action();
      if (!mounted) return;
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignerTile extends StatelessWidget {
  const _SignerTile({
    required this.title,
    required this.data,
  });

  final String title;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? 'created').toString();
    final email = data['email']?.toString();
    final signedAt = data['signedAt']?.toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text((data['name'] ?? 'Signer').toString()),
          if (email != null && email.isNotEmpty)
            Text(email, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 6),
          Text('Status: $status'),
          if (signedAt != null && signedAt.isNotEmpty)
            Text('Signed at: $signedAt'),
        ],
      ),
    );
  }
}
