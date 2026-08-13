// Replaces the empty AgreementPdfStub.
// This file keeps the same class name so no other imports break.
//
// What it does:
//  1. Renders the agreement body in a clean, contract-style layout
//  2. "Generate PDF" — calls AgreementService.generatePdfAndUpload()
//  3. "Send for e-sign" — calls AgreementService.sendForEsign()
//  4. Shows real-time esignStatus badge (not_sent / pending_buyer /
//     pending_seller / completed / declined / voided)
//  5. "Open signed PDF" once esignStatus == completed
//  6. Sync button to pull latest status from backend

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../colors.dart';
import 'agreement_service.dart';

class AgreementPdfStub extends StatefulWidget {
  /// Raw agreement text body (shown in the scrollable contract area).
  final String documentBody;

  /// Firestore agreement document ID — required to call services.
  final String? agreementId;

  /// Already-generated (unsigned) PDF download URL, if any.
  final String? pdfUrl;

  const AgreementPdfStub({
    super.key,
    required this.documentBody,
    this.agreementId,
    this.pdfUrl,
  });

  @override
  State<AgreementPdfStub> createState() => _AgreementPdfStubState();
}

class _AgreementPdfStubState extends State<AgreementPdfStub> {
  final _service = AgreementService();

  bool _generatingPdf = false;
  bool _sendingEsign = false;
  bool _syncing = false;

  String? _pdfUrl;

  @override
  void initState() {
    super.initState();
    _pdfUrl = widget.pdfUrl;
  }

  // ─────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────

  Future<void> _generatePdf() async {
    final id = widget.agreementId;
    if (id == null) return;
    setState(() => _generatingPdf = true);
    try {
      final url = await _service.generatePdfAndUpload(id);
      setState(() => _pdfUrl = url);
      _snack('PDF generated successfully', success: true);
    } catch (e) {
      _snack('Failed to generate PDF: $e');
    } finally {
      setState(() => _generatingPdf = false);
    }
  }

  Future<void> _sendForEsign() async {
    final id = widget.agreementId;
    if (id == null) return;
    setState(() => _sendingEsign = true);
    try {
      await _service.sendForEsign(id);
      _snack(
        'Sent for signatures — both parties will receive an email',
        success: true,
      );
    } catch (e) {
      _snack('Failed to send for e-sign: $e');
    } finally {
      setState(() => _sendingEsign = false);
    }
  }

  Future<void> _syncStatus() async {
    final id = widget.agreementId;
    if (id == null) return;
    setState(() => _syncing = true);
    try {
      await _service.syncSignatureStatus(id);
      _snack('Status updated', success: true);
    } catch (e) {
      _snack('Could not sync: $e');
    } finally {
      setState(() => _syncing = false);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _snack('Could not open URL');
    }
  }

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final agreementId = widget.agreementId;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Agreement Document'),
        actions: [
          if (agreementId != null)
            IconButton(
              tooltip: 'Sync signature status',
              onPressed: _syncing ? null : _syncStatus,
              icon: _syncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
            ),
        ],
      ),
      body: agreementId == null
          // No ID — just render the document body (preview mode)
          ? _ContractBody(body: widget.documentBody)
          // Full live mode — stream real-time Firestore status
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('agreements')
                  .doc(agreementId)
                  .snapshots(),
              builder: (context, snap) {
                final data = snap.data?.data() ?? {};
                final esignStatus = (data['esignStatus'] ?? 'not_sent')
                    .toString();
                final signedPdfUrl = data['signedPdfUrl']?.toString();
                final livePdfUrl = data['pdfUrl']?.toString() ?? _pdfUrl;

                return Column(
                  children: [
                    // Status banner
                    _EsignStatusBanner(status: esignStatus),

                    // Contract body
                    Expanded(child: _ContractBody(body: widget.documentBody)),

                    // Action bar
                    _ActionBar(
                      esignStatus: esignStatus,
                      pdfUrl: livePdfUrl,
                      signedPdfUrl: signedPdfUrl,
                      generatingPdf: _generatingPdf,
                      sendingEsign: _sendingEsign,
                      onGeneratePdf: _generatePdf,
                      onSendEsign: _sendForEsign,
                      onOpenPdf: () => _openUrl(livePdfUrl!),
                      onOpenSignedPdf: () => _openUrl(signedPdfUrl!),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

// ─────────────────────────────────────────
// CONTRACT BODY
// ─────────────────────────────────────────

class _ContractBody extends StatelessWidget {
  final String body;
  const _ContractBody({required this.body});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SelectableText(
          body,
          style: const TextStyle(
            fontSize: 14.5,
            height: 1.75,
            color: Color(0xFF1A1A2E),
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// E-SIGN STATUS BANNER
// ─────────────────────────────────────────

class _EsignStatusBanner extends StatelessWidget {
  final String status;
  const _EsignStatusBanner({required this.status});

  static const _config = {
    'not_sent': (
      color: Color(0xFFF3F4F6),
      textColor: Color(0xFF6B7280),
      icon: Icons.edit_document,
      label: 'Draft — not sent for signature yet',
    ),
    'pending_buyer': (
      color: Color(0xFFFFFBEB),
      textColor: Color(0xFFD97706),
      icon: Icons.pending_outlined,
      label: 'Waiting for buyer signature',
    ),
    'pending_seller': (
      color: Color(0xFFFFFBEB),
      textColor: Color(0xFFD97706),
      icon: Icons.pending_outlined,
      label: 'Waiting for seller signature',
    ),
    'completed': (
      color: Color(0xFFECFDF5),
      textColor: Color(0xFF059669),
      icon: Icons.verified_outlined,
      label: 'Signed by all parties ✓',
    ),
    'declined': (
      color: Color(0xFFFEF2F2),
      textColor: Color(0xFFDC2626),
      icon: Icons.cancel_outlined,
      label: 'Signature declined',
    ),
    'voided': (
      color: Color(0xFFFEF2F2),
      textColor: Color(0xFFDC2626),
      icon: Icons.block_outlined,
      label: 'Agreement voided',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final cfg =
        _config[status] ??
        (
          color: const Color(0xFFF3F4F6),
          textColor: const Color(0xFF6B7280),
          icon: Icons.info_outline,
          label: status,
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: cfg.color,
      child: Row(
        children: [
          Icon(cfg.icon, size: 18, color: cfg.textColor),
          const SizedBox(width: 8),
          Text(
            cfg.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cfg.textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// ACTION BAR
// ─────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final String esignStatus;
  final String? pdfUrl;
  final String? signedPdfUrl;
  final bool generatingPdf;
  final bool sendingEsign;
  final VoidCallback onGeneratePdf;
  final VoidCallback onSendEsign;
  final VoidCallback onOpenPdf;
  final VoidCallback onOpenSignedPdf;

  const _ActionBar({
    required this.esignStatus,
    required this.pdfUrl,
    required this.signedPdfUrl,
    required this.generatingPdf,
    required this.sendingEsign,
    required this.onGeneratePdf,
    required this.onSendEsign,
    required this.onOpenPdf,
    required this.onOpenSignedPdf,
  });

  bool get _pdfReady => pdfUrl != null && pdfUrl!.isNotEmpty;
  bool get _signed =>
      esignStatus == 'completed' &&
      signedPdfUrl != null &&
      signedPdfUrl!.isNotEmpty;
  bool get _inProgress =>
      esignStatus == 'pending_buyer' || esignStatus == 'pending_seller';
  bool get _done =>
      esignStatus == 'completed' ||
      esignStatus == 'declined' ||
      esignStatus == 'voided';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1 — PDF actions
          Row(
            children: [
              if (!_pdfReady) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    style: AppButtons.primary,
                    onPressed: generatingPdf ? null : onGeneratePdf,
                    icon: generatingPdf
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(generatingPdf ? 'Generating…' : 'Generate PDF'),
                  ),
                ),
              ] else ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenPdf,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('View PDF'),
                  ),
                ),
              ],
            ],
          ),

          // Row 2 — E-sign action
          if (_pdfReady && !_done) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: _inProgress
                    ? ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade700,
                      )
                    : AppButtons.primary,
                onPressed: sendingEsign || _inProgress ? null : onSendEsign,
                icon: sendingEsign
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _inProgress ? Icons.hourglass_top : Icons.draw_outlined,
                      ),
                label: Text(
                  sendingEsign
                      ? 'Sending…'
                      : _inProgress
                      ? 'Awaiting signatures…'
                      : 'Send for e-sign',
                ),
              ),
            ),
          ],

          // Signed PDF
          if (_signed) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                ),
                onPressed: onOpenSignedPdf,
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Download Signed Agreement'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
