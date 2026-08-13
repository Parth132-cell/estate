import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/colors.dart';
import 'package:estatex_app/contact/contact_chat_screen.dart';
import 'package:estatex_app/screens/broker_deals_screen.dart';
import 'package:estatex_app/screens/broker_leads_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BrokerProfileScreen extends StatelessWidget {
  final String brokerId;
  final String? propertyId;
  final String? propertyTitle;

  const BrokerProfileScreen({
    super.key,
    required this.brokerId,
    this.propertyId,
    this.propertyTitle,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedBrokerId = brokerId.trim();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwnProfile = currentUserId == normalizedBrokerId;
    final canContact = currentUserId != null && !isOwnProfile;

    if (normalizedBrokerId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Broker Profile')),
        body: const Center(child: Text('Broker details unavailable')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Broker Profile'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: isOwnProfile
            ? [
                IconButton(
                  tooltip: 'My Leads',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BrokerLeadsScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.people_outline),
                ),
                IconButton(
                  tooltip: 'My Deals',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BrokerDealsScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.handshake_outlined),
                ),
              ]
            : null,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(normalizedBrokerId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snapshot.data?.data();
          if (user == null) {
            return const Center(child: Text('Broker not found'));
          }

          final name = (user['name'] ?? 'Broker').toString();
          final isVerified =
              user['isVerifiedBroker'] == true ||
              user['brokerApprovalStatus'] == 'approved';
          // Use avgRating — the field written by ReviewService
          final avgRating = (user['avgRating'] as num?)?.toDouble() ?? 0.0;
          final reviewCount = (user['reviewCount'] as num?)?.toInt() ?? 0;
          final reraNumber = (user['reraNumber'] ?? '').toString();
          final profileImage = (user['profileImage'] ?? '').toString();

          return SingleChildScrollView(
            child: Column(
              children: [
                // ── Hero header ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 28,
                    horizontal: 20,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Avatar
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: AppColors.primarySoft,
                            backgroundImage: profileImage.isNotEmpty
                                ? NetworkImage(profileImage)
                                : null,
                            child: profileImage.isEmpty
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : 'B',
                                    style: const TextStyle(
                                      fontSize: 32,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          if (isVerified)
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.verified,
                                color: Colors.blue,
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Name
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isVerified ? 'Verified Broker' : 'Broker / Agent',
                        style: TextStyle(
                          fontSize: 13,
                          color: isVerified
                              ? Colors.green.shade700
                              : AppColors.textSecondary,
                          fontWeight: isVerified
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),

                      // Rating
                      if (avgRating > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.amber,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              avgRating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              ' ($reviewCount review${reviewCount == 1 ? '' : 's'})',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],

                      // RERA number
                      if (reraNumber.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                size: 14,
                                color: Colors.green.shade700,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'RERA: $reraNumber',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ⚠️ NO PHONE NUMBER SHOWN — contact via app only
                      if (!isOwnProfile) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_outline,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Contact via EstateX — details are protected',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Contact buttons
                      if (canContact) ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Chat — primary
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ContactChatScreen(
                                    brokerId: normalizedBrokerId,
                                    propertyId: propertyId ?? '',
                                    propertyTitle:
                                        propertyTitle ?? 'Property enquiry',
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.chat_outlined, size: 18),
                              label: const Text('Send Message'),
                            ),
                            const SizedBox(width: 10),
                            // Callback request — goes through chat
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () =>
                                  _requestCallback(context, normalizedBrokerId),
                              icon: const Icon(
                                Icons.schedule_outlined,
                                size: 18,
                              ),
                              label: const Text('Request Callback'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Properties by this broker ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text(
                        'Properties',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('properties')
                            .where('uploadedBy', isEqualTo: normalizedBrokerId)
                            .where('verificationStatus', isEqualTo: 'approved')
                            .snapshots(),
                        builder: (_, snap) => Text(
                          '${snap.data?.docs.length ?? 0} listings',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('properties')
                      .where('uploadedBy', isEqualTo: normalizedBrokerId)
                      .where('verificationStatus', isEqualTo: 'approved')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, propertySnap) {
                    if (propertySnap.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text('Error: ${propertySnap.error}'),
                      );
                    }
                    if (propertySnap.connectionState ==
                        ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      );
                    }

                    final properties = propertySnap.data?.docs ?? [];
                    if (properties.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No active listings',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: properties.length,
                      itemBuilder: (context, index) {
                        final data = properties[index].data();
                        final images = (data['images'] as List? ?? []);
                        final price = (data['price'] as num?)?.toInt() ?? 0;
                        final title = (data['title'] ?? '').toString();
                        final city = (data['city'] ?? '').toString();
                        final category =
                            (data['propertyCategory'] ?? 'apartment')
                                .toString();
                        final bhk = (data['bhk'] as num?)?.toInt() ?? 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  bottomLeft: Radius.circular(12),
                                ),
                                child: images.isNotEmpty
                                    ? Image.network(
                                        images.first.toString(),
                                        width: 90,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _imgPlaceholder(),
                                      )
                                    : _imgPlaceholder(),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        city,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            _fmtPrice(price),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          const Spacer(),
                                          if (bhk > 0)
                                            Text(
                                              '$bhk BHK · ',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          Text(
                                            _catLabel(category),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
    width: 90,
    height: 80,
    color: Colors.grey.shade200,
    child: const Icon(Icons.home_outlined, color: Colors.grey, size: 28),
  );

  String _fmtPrice(int v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(0)}L';
    return '₹$v';
  }

  String _catLabel(String cat) {
    const m = {
      'apartment': 'Apartment',
      'house': 'House',
      'villa': 'Villa',
      'residential_plot': 'Plot',
      'agricultural_land': 'Land',
      'office_space': 'Office',
      'retail_shop': 'Shop',
      'warehouse': 'Warehouse',
      'pg_hostel': 'PG',
      'flat_rent': 'Rental',
    };
    return m[cat] ?? cat;
  }

  /// Request callback goes through in-app chat — no phone numbers exchanged
  Future<void> _requestCallback(BuildContext context, String brokerId) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactChatScreen(
          brokerId: brokerId,
          propertyId: propertyId ?? '',
          propertyTitle: propertyTitle ?? 'Property enquiry',
        ),
      ),
    );
    // The chat will open with a pre-filled message
    await Future.delayed(const Duration(milliseconds: 400));
    // Note: we could also pre-fill the message controller with
    // "I'd like to request a callback at your earliest convenience."
    // but ContactChatScreen handles this via the empty chat prompt
  }
}
