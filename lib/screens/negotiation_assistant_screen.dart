import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../colors.dart';

class NegotiationAssistantScreen extends StatefulWidget {
  final int? listedPrice;
  final int? offerPrice;

  const NegotiationAssistantScreen({
    super.key,
    this.listedPrice,
    this.offerPrice,
  });

  @override
  State<NegotiationAssistantScreen> createState() =>
      _NegotiationAssistantScreenState();
}

class _NegotiationAssistantScreenState
    extends State<NegotiationAssistantScreen> {
  final _listedCtrl = TextEditingController();
  final _offerCtrl = TextEditingController();
  final _counterCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  _NegotiationResult? _result;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.listedPrice != null) {
      _listedCtrl.text = widget.listedPrice.toString();
    }
    if (widget.offerPrice != null) {
      _offerCtrl.text = widget.offerPrice.toString();
    }
  }

  @override
  void dispose() {
    _listedCtrl.dispose();
    _offerCtrl.dispose();
    _counterCtrl.dispose();
    _cityCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _runAssistant() async {
    final listed = int.tryParse(_listedCtrl.text.trim());
    final offer = int.tryParse(_offerCtrl.text.trim());
    final counter = int.tryParse(_counterCtrl.text.trim());
    final city = _cityCtrl.text.trim();
    final notes = _notesCtrl.text.trim();

    if (listed == null || listed <= 0) {
      _setError('Please enter a valid listed price');
      return;
    }
    if (offer == null || offer <= 0) {
      _setError('Please enter a valid offer price');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final prompt =
          '''
You are an expert real estate negotiation advisor for the Indian market. 
Analyze the following deal and give strategic advice.

Listed price: ₹$listed
Buyer's current offer: ₹$offer
${counter != null ? 'Seller counter offer: ₹$counter' : 'No counter offer yet.'}
${city.isNotEmpty ? 'City/location: $city' : ''}
${notes.isNotEmpty ? 'Additional context: $notes' : ''}

Respond ONLY with a JSON object in this exact format, no markdown:
{
  "strategy": "one of: accept | counter | hold | walk_away",
  "suggestedCounter": <integer rupee amount>,
  "confidence": <integer 1-100>,
  "analysis": "<2-3 sentence analysis of the gap and market position>",
  "negotiationScript": ["<step 1>", "<step 2>", "<step 3>"],
  "redFlags": ["<any concern or empty array>"],
  "marketInsight": "<one sentence about typical negotiation range for Indian real estate>"
}
''';

      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'claude-sonnet-4-6',
          'max_tokens': 1000,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final text = (body['content'] as List)
            .whereType<Map>()
            .where((b) => b['type'] == 'text')
            .map((b) => b['text'].toString())
            .join('');

        final clean = text
            .trim()
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        final parsed = jsonDecode(clean) as Map<String, dynamic>;

        setState(() {
          _result = _NegotiationResult.fromMap(parsed);
          _loading = false;
        });
      } else {
        _setError('AI service error. Try again in a moment.');
      }
    } catch (e) {
      _setError('Could not get advice: $e');
    }
  }

  void _setError(String msg) {
    setState(() {
      _error = msg;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Negotiation Assistant'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Negotiation Advisor',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Powered by Claude — get a data-driven strategy',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Inputs
          _InputCard(
            listedCtrl: _listedCtrl,
            offerCtrl: _offerCtrl,
            counterCtrl: _counterCtrl,
            cityCtrl: _cityCtrl,
            notesCtrl: _notesCtrl,
          ),

          const SizedBox(height: 16),

          // Error
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 13),
              ),
            ),

          // CTA
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: AppButtons.primary,
              onPressed: _loading ? null : _runAssistant,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(
                _loading ? 'Analyzing deal…' : 'Get AI Strategy',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Result
          if (_result != null) ...[
            const SizedBox(height: 24),
            _ResultCard(result: _result!),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// INPUT CARD
// ─────────────────────────────────────────

class _InputCard extends StatelessWidget {
  final TextEditingController listedCtrl;
  final TextEditingController offerCtrl;
  final TextEditingController counterCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController notesCtrl;

  const _InputCard({
    required this.listedCtrl,
    required this.offerCtrl,
    required this.counterCtrl,
    required this.cityCtrl,
    required this.notesCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  controller: listedCtrl,
                  label: 'Listed Price (₹)',
                  hint: 'e.g. 8500000',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NumberField(
                  controller: offerCtrl,
                  label: 'Your Offer (₹)',
                  hint: 'e.g. 7500000',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  controller: counterCtrl,
                  label: 'Seller Counter (₹)',
                  hint: 'optional',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TextField(
                  controller: cityCtrl,
                  label: 'City',
                  hint: 'e.g. Ahmedabad',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TextField(
            controller: notesCtrl,
            label: 'Extra context (optional)',
            hint: 'e.g. property vacant 6 months, seller keen to close',
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;

  const _NumberField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        isDense: true,
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;

  const _TextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        isDense: true,
      ),
    );
  }
}

// ─────────────────────────────────────────
// RESULT CARD
// ─────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final _NegotiationResult result;
  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Strategy + confidence
        _StrategyBanner(
          strategy: result.strategy,
          suggestedCounter: result.suggestedCounter,
          confidence: result.confidence,
        ),
        const SizedBox(height: 12),

        // Analysis
        _Section(
          icon: Icons.analytics_outlined,
          title: 'Analysis',
          child: Text(
            result.analysis,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Market insight
        _Section(
          icon: Icons.insights_outlined,
          title: 'Market Insight',
          child: Text(
            result.marketInsight,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Script
        _Section(
          icon: Icons.chat_outlined,
          title: 'Negotiation Script',
          child: Column(
            children: result.negotiationScript
                .asMap()
                .entries
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${e.key + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            e.value,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),

        // Red flags
        if (result.redFlags.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Section(
            icon: Icons.warning_amber_outlined,
            title: 'Watch out for',
            iconColor: Colors.orange.shade700,
            child: Column(
              children: result.redFlags
                  .map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 16,
                            color: Colors.orange.shade600,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              f,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange.shade800,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _StrategyBanner extends StatelessWidget {
  final String strategy;
  final int suggestedCounter;
  final int confidence;

  const _StrategyBanner({
    required this.strategy,
    required this.suggestedCounter,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    final (color, bg, icon, label) = switch (strategy) {
      'accept' => (
        Colors.green.shade700,
        Colors.green.shade50,
        Icons.check_circle_outline,
        'Accept the offer',
      ),
      'walk_away' => (
        Colors.red.shade700,
        Colors.red.shade50,
        Icons.directions_walk,
        'Walk away',
      ),
      'hold' => (
        Colors.orange.shade700,
        Colors.orange.shade50,
        Icons.pause_circle_outline,
        'Hold your position',
      ),
      _ => (
        AppColors.primary,
        const Color(0xFFEFF4FF),
        Icons.swap_horiz,
        'Counter offer',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Strategy: $label',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (suggestedCounter > 0)
                  Text(
                    'Suggested counter: ₹${_fmt(suggestedCounter)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: color.withOpacity(0.8),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                '$confidence%',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                'confidence',
                style: TextStyle(fontSize: 10, color: color.withOpacity(0.7)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(int v) {
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    return v.toString();
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Color? iconColor;

  const _Section({
    required this.icon,
    required this.title,
    required this.child,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor ?? AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────

class _NegotiationResult {
  final String strategy;
  final int suggestedCounter;
  final int confidence;
  final String analysis;
  final List<String> negotiationScript;
  final List<String> redFlags;
  final String marketInsight;

  const _NegotiationResult({
    required this.strategy,
    required this.suggestedCounter,
    required this.confidence,
    required this.analysis,
    required this.negotiationScript,
    required this.redFlags,
    required this.marketInsight,
  });

  factory _NegotiationResult.fromMap(Map<String, dynamic> m) {
    return _NegotiationResult(
      strategy: (m['strategy'] ?? 'counter').toString(),
      suggestedCounter: (m['suggestedCounter'] as num?)?.toInt() ?? 0,
      confidence: (m['confidence'] as num?)?.toInt() ?? 70,
      analysis: (m['analysis'] ?? '').toString(),
      negotiationScript: (m['negotiationScript'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      redFlags: (m['redFlags'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      marketInsight: (m['marketInsight'] ?? '').toString(),
    );
  }
}
