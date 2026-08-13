import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/property_services.dart';
import 'property_details_screen.dart';
import 'property_listing_status.dart';
import 'seller_property_editor_screen.dart';

class SellerListingsManagementView extends StatefulWidget {
  const SellerListingsManagementView({super.key, required this.userId});

  final String userId;

  @override
  State<SellerListingsManagementView> createState() =>
      _SellerListingsManagementViewState();
}

class _SellerListingsManagementViewState
    extends State<SellerListingsManagementView> {
  final PropertyService _propertyService = PropertyService();
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('properties')
          .where('uploadedBy', isEqualTo: widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Unable to load properties: ${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
              snapshot.data?.docs ?? const [],
            )..sort((a, b) {
              final aData = a.data();
              final bData = b.data();
              final aTime =
                  (aData['lastSellerActionAt'] ??
                          aData['updatedAt'] ??
                          aData['createdAt'])
                      as Timestamp?;
              final bTime =
                  (bData['lastSellerActionAt'] ??
                          bData['updatedAt'] ??
                          bData['createdAt'])
                      as Timestamp?;
              final aMillis = aTime?.millisecondsSinceEpoch ?? 0;
              final bMillis = bTime?.millisecondsSinceEpoch ?? 0;
              return bMillis.compareTo(aMillis);
            });

        if (docs.isEmpty) {
          return const Center(
            child: Text('You have not added any properties yet'),
          );
        }

        final filteredDocs = docs
            .where((doc) => _matchesFilter(doc.data()))
            .toList(growable: false);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SummarySection(
              counts: _buildCounts(docs),
              selectedFilter: _selectedFilter,
              onFilterChanged: (value) {
                setState(() => _selectedFilter = value);
              },
            ),
            const SizedBox(height: 20),
            if (filteredDocs.isEmpty)
              const _EmptyFilterState()
            else
              ...filteredDocs.map(
                (doc) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _ListingCard(
                    data: doc.data(),
                    onView: () => _openDetails(context, doc.id, doc.data()),
                    onEdit: () => _openEditor(context, doc.id, doc.data()),
                    onResubmit: () => _openEditor(context, doc.id, doc.data()),
                    onMarkSold: () => _markAsSold(doc.id),
                    onArchive: () => _archiveListing(doc.id),
                    onRestore: () => _restoreListing(doc.id),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Map<String, int> _buildCounts(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final counts = <String, int>{
      'all': docs.length,
      'live': 0,
      'review': 0,
      'rejected': 0,
      'draft': 0,
      'sold': 0,
      'archived': 0,
    };

    for (final doc in docs) {
      final data = doc.data();
      final listingStatus =
          (data['listingStatus'] ?? PropertyListingStatus.active).toString();
      final verificationStatus =
          (data['verificationStatus'] ?? PropertyVerificationStatus.pending)
              .toString();

      if (listingStatus == PropertyListingStatus.archived) {
        counts['archived'] = (counts['archived'] ?? 0) + 1;
      } else if (listingStatus == PropertyListingStatus.sold) {
        counts['sold'] = (counts['sold'] ?? 0) + 1;
      } else if (listingStatus == PropertyListingStatus.draft ||
          verificationStatus == PropertyVerificationStatus.draft) {
        counts['draft'] = (counts['draft'] ?? 0) + 1;
      } else if (verificationStatus == PropertyVerificationStatus.rejected) {
        counts['rejected'] = (counts['rejected'] ?? 0) + 1;
      } else if (verificationStatus == PropertyVerificationStatus.approved) {
        counts['live'] = (counts['live'] ?? 0) + 1;
      } else {
        counts['review'] = (counts['review'] ?? 0) + 1;
      }
    }

    return counts;
  }

  bool _matchesFilter(Map<String, dynamic> data) {
    if (_selectedFilter == 'all') {
      return true;
    }

    final listingStatus =
        (data['listingStatus'] ?? PropertyListingStatus.active).toString();
    final verificationStatus =
        (data['verificationStatus'] ?? PropertyVerificationStatus.pending)
            .toString();

    return switch (_selectedFilter) {
      'live' =>
        listingStatus == PropertyListingStatus.active &&
            verificationStatus == PropertyVerificationStatus.approved,
      'review' =>
        listingStatus == PropertyListingStatus.active &&
            verificationStatus == PropertyVerificationStatus.pending,
      'rejected' =>
        listingStatus == PropertyListingStatus.active &&
            verificationStatus == PropertyVerificationStatus.rejected,
      'draft' =>
        listingStatus == PropertyListingStatus.draft ||
            verificationStatus == PropertyVerificationStatus.draft,
      'sold' => listingStatus == PropertyListingStatus.sold,
      'archived' => listingStatus == PropertyListingStatus.archived,
      _ => true,
    };
  }

  void _openDetails(
    BuildContext context,
    String propertyId,
    Map<String, dynamic> data,
  ) {
    final images = ((data['images'] as List?) ?? const [])
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PropertyDetailsScreen(
          propertyId: propertyId,
          imageUrl: images.isNotEmpty ? images.first : '',
          price: 'Rs ${data['price'] ?? 0}',
          title: (data['title'] ?? '').toString(),
          location: _locationText(data),
          bhk: '${data['bhk'] ?? '-'} BHK',
          brokerId: (data['uploadedBy'] ?? '').toString(),
          imageUrls: images,
          verified: data['verificationStatus'] == 'approved',
        ),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    String propertyId,
    Map<String, dynamic> data,
  ) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SellerPropertyEditorScreen(
          propertyId: propertyId,
          initialData: data,
        ),
      ),
    );
  }

  Future<void> _markAsSold(String propertyId) async {
    final confirmed = await _confirmAction(
      title: 'Mark listing as sold?',
      message:
          'This will hide the property from active inventory and label it as sold.',
      confirmLabel: 'Mark Sold',
    );
    if (!confirmed || !mounted) return;

    await _runListingAction(
      action: () => _propertyService.markAsSold(propertyId),
      successMessage: 'Listing marked as sold',
    );
  }

  Future<void> _archiveListing(String propertyId) async {
    final confirmed = await _confirmAction(
      title: 'Archive listing?',
      message:
          'Archived listings stay in your dashboard but are treated as inactive.',
      confirmLabel: 'Archive',
    );
    if (!confirmed || !mounted) return;

    await _runListingAction(
      action: () => _propertyService.archiveListing(propertyId),
      successMessage: 'Listing archived',
    );
  }

  Future<void> _restoreListing(String propertyId) async {
    await _runListingAction(
      action: () => _propertyService.restoreListing(propertyId),
      successMessage: 'Listing restored',
    );
  }

  Future<void> _runListingAction({
    required Future<void> Function() action,
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
      ).showSnackBar(SnackBar(content: Text('Unable to update listing: $e')));
    }
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.counts,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  final Map<String, int> counts;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final chips = <({String key, String label})>[
      (key: 'all', label: 'All'),
      (key: 'live', label: 'Live'),
      (key: 'review', label: 'In Review'),
      (key: 'rejected', label: 'Rejected'),
      (key: 'draft', label: 'Drafts'),
      (key: 'sold', label: 'Sold'),
      (key: 'archived', label: 'Archived'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E8EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${counts['all'] ?? 0} total listings',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Manage drafts, resubmissions, sold inventory, and archived stock from one place.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips.map((chip) {
              final selected = selectedFilter == chip.key;
              final count = counts[chip.key] ?? 0;
              return ChoiceChip(
                label: Text('${chip.label} ($count)'),
                selected: selected,
                onSelected: (_) => onFilterChanged(chip.key),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({
    required this.data,
    required this.onView,
    required this.onEdit,
    required this.onResubmit,
    required this.onMarkSold,
    required this.onArchive,
    required this.onRestore,
  });

  final Map<String, dynamic> data;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onResubmit;
  final VoidCallback onMarkSold;
  final VoidCallback onArchive;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final images = ((data['images'] as List?) ?? const [])
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
    final imageUrl = images.isNotEmpty ? images.first : '';
    final lifecycle = propertyLifecycleLabel(data);
    final listingStatus =
        (data['listingStatus'] ?? PropertyListingStatus.active).toString();
    final verificationStatus =
        (data['verificationStatus'] ?? PropertyVerificationStatus.pending)
            .toString();
    final rejectionReason = (data['rejectionReason'] ?? '').toString().trim();

    final canEdit =
        listingStatus != PropertyListingStatus.sold &&
        listingStatus != PropertyListingStatus.archived;
    final canResubmit =
        listingStatus == PropertyListingStatus.active &&
        verificationStatus == PropertyVerificationStatus.rejected;
    final canMarkSold =
        listingStatus == PropertyListingStatus.active &&
        verificationStatus == PropertyVerificationStatus.approved;
    final canArchive = listingStatus != PropertyListingStatus.archived;
    final canRestore = listingStatus == PropertyListingStatus.archived;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7EBF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Stack(
              children: [
                imageUrl.isEmpty
                    ? Container(
                        height: 180,
                        color: const Color(0xFFF1F3F6),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.home_work_outlined,
                          size: 48,
                          color: Colors.grey,
                        ),
                      )
                    : Image.network(
                        imageUrl,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return Container(
                            height: 180,
                            color: const Color(0xFFF1F3F6),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.image_not_supported_outlined,
                              size: 42,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: _LifecycleBadge(data: data, label: lifecycle),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.62),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${images.length} photos',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rs ${data['price'] ?? 0}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  (data['title'] ?? 'Untitled property').toString(),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _locationText(data),
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 6),
                Text(
                  '${data['bhk'] ?? '-'} BHK  |  ${data['listingType'] ?? 'listing'}',
                  style: const TextStyle(color: Colors.black54),
                ),
                if (verificationStatus == PropertyVerificationStatus.rejected &&
                    rejectionReason.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4F1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFFD1C4)),
                    ),
                    child: Text(
                      'Rejection reason: $rejectionReason',
                      style: const TextStyle(
                        color: Color(0xFF9B3B24),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onView,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('View'),
                    ),
                    if (canEdit)
                      OutlinedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                      ),
                    if (canResubmit)
                      ElevatedButton.icon(
                        onPressed: onResubmit,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Resubmit'),
                      ),
                    if (canMarkSold)
                      OutlinedButton.icon(
                        onPressed: onMarkSold,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Mark Sold'),
                      ),
                    if (canArchive)
                      OutlinedButton.icon(
                        onPressed: onArchive,
                        icon: const Icon(Icons.archive_outlined),
                        label: const Text('Archive'),
                      ),
                    if (canRestore)
                      ElevatedButton.icon(
                        onPressed: onRestore,
                        icon: const Icon(Icons.unarchive_outlined),
                        label: const Text('Restore'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LifecycleBadge extends StatelessWidget {
  const _LifecycleBadge({required this.data, required this.label});

  final Map<String, dynamic> data;
  final String label;

  @override
  Widget build(BuildContext context) {
    final listingStatus =
        (data['listingStatus'] ?? PropertyListingStatus.active).toString();
    final verificationStatus =
        (data['verificationStatus'] ?? PropertyVerificationStatus.pending)
            .toString();

    final background = switch ((listingStatus, verificationStatus)) {
      (PropertyListingStatus.sold, _) => const Color(0xFF165B33),
      (PropertyListingStatus.archived, _) => const Color(0xFF465264),
      (PropertyListingStatus.draft, _) => const Color(0xFF6B4EFF),
      (_, PropertyVerificationStatus.approved) => const Color(0xFF0F9D58),
      (_, PropertyVerificationStatus.rejected) => const Color(0xFFD94F2B),
      _ => const Color(0xFFF39C12),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _EmptyFilterState extends StatelessWidget {
  const _EmptyFilterState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E7EF)),
      ),
      child: const Column(
        children: [
          Icon(Icons.inbox_outlined, size: 36, color: Colors.black45),
          SizedBox(height: 12),
          Text(
            'No listings in this section yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6),
          Text(
            'Try another filter to view the rest of your inventory.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

String _locationText(Map<String, dynamic> data) {
  final city = (data['city'] ?? '').toString().trim();
  final locality = (data['locality'] ?? '').toString().trim();
  if (city.isEmpty && locality.isEmpty) {
    return 'Location not added';
  }
  if (city.isEmpty) {
    return locality;
  }
  if (locality.isEmpty) {
    return city;
  }
  return '$locality, $city';
}
