import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/services/saved_service.dart';
import 'package:flutter/material.dart';

class CompareScreen extends StatelessWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = SavedService();

    return Scaffold(
      appBar: AppBar(title: const Text('Compare Properties')),
      body: StreamBuilder<List<String>>(
        stream: service.comparisonIds(),
        initialData: const <String>[],
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Unable to load comparison list: ${snapshot.error}'),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final ids = snapshot.data ?? const <String>[];
          final selectedIds = ids.take(SavedService.maxComparisonCount).toList();

          if (selectedIds.length < 2) {
            return const Center(
              child: Text('Select at least 2 properties to compare'),
            );
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('properties')
                .where(FieldPath.documentId, whereIn: selectedIds)
                .snapshots(),
            builder: (context, propertySnap) {
              if (propertySnap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Unable to load compared properties: ${propertySnap.error}'),
                  ),
                );
              }

              if (propertySnap.connectionState == ConnectionState.waiting && !propertySnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final queryDocs = propertySnap.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];

              final docsById = {
                for (final doc in queryDocs) doc.id: doc,
              };
              final properties = selectedIds
                  .map((id) => docsById[id])
                  .whereType<QueryDocumentSnapshot<Map<String, dynamic>>>()
                  .toList();

              if (properties.length < 2) {
                return const Center(
                  child: Text('Unable to load selected properties right now.'),
                );
              }

              final bestValueIndex = _findBestValueIndex(properties);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < properties.length; i++)
                      _ComparisonColumn(
                        doc: properties[i],
                        isBestValue: i == bestValueIndex,
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  int? _findBestValueIndex(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    var bestIndex = -1;
    var bestScore = double.infinity;

    for (var i = 0; i < docs.length; i++) {
      final data = docs[i].data();
      final price = _asDouble(data['price']);
      final area = _resolveArea(data);
      if (price == null || area == null || area <= 0) continue;

      final score = price / area;
      if (score < bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }

    return bestIndex >= 0 ? bestIndex : null;
  }

  double? _resolveArea(Map<String, dynamic> data) {
    return _asDouble(data['areaSqft']) ?? _asDouble(data['area']) ?? _asDouble(data['superArea']);
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '').trim());
  }
}

class _ComparisonColumn extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool isBestValue;

  const _ComparisonColumn({required this.doc, required this.isBestValue});

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final title = (data['title'] ?? 'Untitled').toString();
    final price = data['price']?.toString() ?? 'N/A';
    final area = data['areaSqft']?.toString() ?? data['area']?.toString() ?? 'N/A';
    final location = data['city']?.toString() ?? data['location']?.toString() ?? 'N/A';
    final amenities = _formatAmenities(data['amenities']);

    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBestValue ? Colors.green : Colors.grey.shade300,
          width: isBestValue ? 2 : 1,
        ),
        boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => SavedService().toggleComparison(doc.id),
                tooltip: 'Remove from comparison',
              ),
            ],
          ),
          if (isBestValue)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Chip(
                label: Text('Best Value'),
                backgroundColor: Color(0xFFE7F7EC),
              ),
            ),
          _row('Price', '₹$price'),
          _row('Area', '$area sq ft'),
          _row('Location', location),
          _row('Amenities', amenities),
        ],
      ),
    );
  }

  String _formatAmenities(dynamic value) {
    if (value is List) {
      final items = value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      if (items.isEmpty) return 'N/A';
      return items.take(4).join(', ');
    }
    if (value == null) return 'N/A';
    final text = value.toString().trim();
    return text.isEmpty ? 'N/A' : text;
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
