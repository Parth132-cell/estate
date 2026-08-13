import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/services/app_analytics_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../colors.dart';
import '../explore/explore_search_screen.dart';
import '../property/add_property/add_property_screen.dart';
import '../property/property_card.dart';
import '../property/property_card_skeleton.dart' hide PropertyCardSkeleton;
import '../property/property_details_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: user == null
          ? const _StaticHome()
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, snap) {
                final data = snap.data?.data() ?? {};
                return _PersonalisedHome(userData: data, uid: user.uid);
              },
            ),
    );
  }
}

// ─────────────────────────────────────────
// PERSONALISED HOME (logged in user)
// ─────────────────────────────────────────

class _PersonalisedHome extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String uid;

  const _PersonalisedHome({required this.userData, required this.uid});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _firstName {
    final name = (userData['name'] ?? '').toString().trim();
    if (name.isEmpty) return '';
    return name.split(' ').first;
  }

  String get _role => (userData['role'] ?? 'user').toString();

  Map<String, dynamic> get _prefs =>
      (userData['preferences'] as Map<String, dynamic>?) ?? {};

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── App bar ──
        SliverAppBar(
          floating: true,
          snap: true,
          backgroundColor: AppColors.surface,
          elevation: 0,
          title: Row(
            children: [
              const Text(
                'EstateX',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const Spacer(),
              if (_role == 'broker' || _role == 'seller')
                _RoleBadge(role: _role),
            ],
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Greeting ──
                Text(
                  _firstName.isNotEmpty
                      ? '$_greeting, $_firstName 👋'
                      : '$_greeting 👋',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _buildSubtitle(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Hero CTA card ──
                _HeroCard(role: _role, prefs: _prefs),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),

        // ── AI picks (Claude-powered) ──
        SliverToBoxAdapter(
          child: _AiPicksSection(uid: uid, prefs: _prefs),
        ),

        // ── Featured ──
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
        const SliverToBoxAdapter(child: _FeaturedSection()),

        // ── Recent ──
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
        const SliverToBoxAdapter(child: _RecentSection()),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  String _buildSubtitle() {
    final city = (_prefs['city'] ?? '').toString().trim();
    switch (_role) {
      case 'broker':
        return 'Manage your leads, deals and listings';
      case 'seller':
        return city.isNotEmpty
            ? 'Your properties in $city are live'
            : 'Your listings dashboard';
      default:
        return city.isNotEmpty
            ? 'Showing properties in $city'
            : 'Find your next verified home';
    }
  }
}

// ─────────────────────────────────────────
// STATIC HOME (fallback if no user)
// ─────────────────────────────────────────

class _StaticHome extends StatelessWidget {
  const _StaticHome();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 16),
      children: const [
        _HeroCard(role: 'buyer', prefs: {}),
        SizedBox(height: 28),
        _FeaturedSection(),
        SizedBox(height: 28),
        _RecentSection(),
        SizedBox(height: 32),
      ],
    );
  }
}

// ─────────────────────────────────────────
// ROLE BADGE
// ─────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final label = role == 'broker' ? '🤝 Broker' : '🏠 Seller';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// HERO CARD — role-aware CTAs
// ─────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final String role;
  final Map<String, dynamic> prefs;

  const _HeroCard({required this.role, required this.prefs});

  @override
  Widget build(BuildContext context) {
    final city = (prefs['city'] ?? '').toString().trim();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _heroTitle(city),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _heroSubtitle,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(children: _buildButtons(context)),
        ],
      ),
    );
  }

  String _heroTitle(String city) {
    switch (role) {
      case 'broker':
        return 'Your CRM dashboard';
      case 'seller':
        return 'Manage your listings';
      default:
        return city.isNotEmpty
            ? 'Find homes in $city'
            : 'Find your next verified home';
    }
  }

  String get _heroSubtitle {
    switch (role) {
      case 'broker':
        return 'Track leads, close deals, manage co-brokerage.';
      case 'seller':
        return 'Your listed properties, inquiries and deal status.';
      default:
        return 'Explore trusted listings, compare faster, close securely.';
    }
  }

  List<Widget> _buildButtons(BuildContext context) {
    if (role == 'seller') {
      return [
        _HeroButton(
          label: 'List Property',
          icon: Icons.add_home_work_outlined,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddPropertyScreen()),
          ),
        ),
        const SizedBox(width: 10),
        _HeroButton(
          label: 'My Listings',
          icon: Icons.format_list_bulleted,
          outlined: true,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ExploreSearchScreen()),
          ),
        ),
      ];
    }
    return [
      _HeroButton(
        label: 'Explore',
        icon: Icons.search,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ExploreSearchScreen()),
        ),
      ),
      const SizedBox(width: 10),
      _HeroButton(
        label: 'List Property',
        icon: Icons.add_home_work_outlined,
        outlined: true,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddPropertyScreen()),
        ),
      ),
    ];
  }
}

class _HeroButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool outlined;
  final VoidCallback onTap;

  const _HeroButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white70),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
      );
    }
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1D4ED8),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

// ─────────────────────────────────────────
// AI PICKS SECTION — Claude API
// ─────────────────────────────────────────

class _AiPicksSection extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> prefs;

  const _AiPicksSection({required this.uid, required this.prefs});

  @override
  State<_AiPicksSection> createState() => _AiPicksSectionState();
}

class _AiPicksSectionState extends State<_AiPicksSection> {
  List<Map<String, dynamic>> _picks = [];
  List<String> _pickIds = [];
  bool _loading = true;
  String? _aiReason;

  @override
  void initState() {
    super.initState();
    _loadAiPicks();
  }

  Future<void> _loadAiPicks() async {
    try {
      // 1. Fetch up to 30 approved properties from Firestore
      final snap = await FirebaseFirestore.instance
          .collection('properties')
          .where('verificationStatus', isEqualTo: 'approved')
          .limit(30)
          .get();

      if (snap.docs.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      // 2. Build a compact property list for Claude
      final propertyList = snap.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'title': data['title'] ?? '',
          'city': data['city'] ?? '',
          'locality': data['locality'] ?? '',
          'price': data['price'] ?? 0,
          'bhk': data['bhk'] ?? '',
          'type': data['propertyType'] ?? '',
          'isFeatured': data['isFeatured'] == true,
        };
      }).toList();

      final city = (widget.prefs['city'] ?? '').toString();
      final bhk = widget.prefs['bhk'];
      final budgetMin = widget.prefs['budgetMin'] ?? 0;
      final budgetMax = widget.prefs['budgetMax'] ?? 100000000;

      // 3. Ask Claude to rank and pick top 5
      final prompt =
          '''
You are a real estate recommendation engine for an Indian property app called EstateX.

User preferences:
- Preferred city: ${city.isNotEmpty ? city : 'no preference'}
- Preferred BHK: ${bhk != null ? '$bhk BHK' : 'no preference'}
- Budget: ₹$budgetMin to ₹$budgetMax

Available properties (JSON array):
${jsonEncode(propertyList)}

Task: Pick the top 5 property IDs that best match the user's preferences. Prioritise city match, then BHK match, then price within budget. If no strong match exists, pick the best available.

Respond ONLY with a valid JSON object in exactly this format, no markdown, no explanation:
{"picks":["id1","id2","id3","id4","id5"],"reason":"one sentence explanation in Hindi-English mix or plain English, under 15 words"}
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

        final ids = (parsed['picks'] as List).map((e) => e.toString()).toList();
        final reason = parsed['reason']?.toString();

        // 4. Map IDs back to property data
        final byId = {for (final d in snap.docs) d.id: d.data()};
        final picked = ids
            .where((id) => byId.containsKey(id))
            .map((id) => {'id': id, ...byId[id]!})
            .toList();

        if (!mounted) return;
        setState(() {
          _picks = picked;
          _pickIds = ids;
          _aiReason = reason;
          _loading = false;
        });
      } else {
        _fallback(snap.docs);
      }
    } catch (_) {
      // Graceful fallback — just show featured properties
      try {
        final snap = await FirebaseFirestore.instance
            .collection('properties')
            .where('verificationStatus', isEqualTo: 'approved')
            .where('isFeatured', isEqualTo: true)
            .limit(5)
            .get();
        _fallback(snap.docs);
      } catch (_) {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  void _fallback(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (!mounted) return;
    setState(() {
      _picks = docs.map((d) => {'id': d.id, ...d.data()}).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _picks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'AI Picks for you',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (_aiReason != null && _aiReason!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _aiReason!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          height: 250,
          child: _loading
              ? ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 16),
                  itemCount: 3,
                  itemBuilder: (_, __) => const PropertyCardSkeleton(),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 16),
                  itemCount: _picks.length,
                  itemBuilder: (context, i) {
                    final data = _picks[i];
                    final id = data['id'].toString();
                    final images = (data['images'] as List? ?? [])
                        .map((e) => e.toString())
                        .toList();
                    return PropertyCard(
                      propertyId: id,
                      imageUrl: images.isNotEmpty ? images.first : '',
                      price: '₹${data['price']}',
                      rawPrice: (data['price'] as num?)?.toInt(),
                      title: data['title']?.toString() ?? '',
                      location: data['city']?.toString() ?? '',
                      bhk: '${data['bhk']} BHK',
                      verified:
                          (data['verificationStatus'] ?? '')
                              .toString()
                              .toLowerCase() ==
                          'approved',
                      areaSqft: (data['areaSqft'] as num?)?.toInt(),
                      propertyCategory: data['propertyCategory']?.toString(),
                      isFeatured: data['isFeatured'] == true,
                      listingType: data['listingType']?.toString(),
                      locality: data['locality']?.toString(),
                      onTap: () {
                        AppAnalyticsService.instance.logPropertyViewed(
                          propertyId: id,
                          source: 'ai_picks',
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PropertyDetailsScreen(
                              propertyId: id,
                              imageUrl: images.isNotEmpty ? images.first : '',
                              imageUrls: images,
                              price: '₹${data['price']}',
                              title: data['title']?.toString() ?? '',
                              location: data['city']?.toString() ?? '',
                              bhk: '${data['bhk']} BHK',
                              brokerId: data['uploadedBy']?.toString() ?? '',
                              verified: true,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// FEATURED SECTION (unchanged logic, tidied)
// ─────────────────────────────────────────

class _FeaturedSection extends StatelessWidget {
  const _FeaturedSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Featured Properties',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 250,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('properties')
                .where('verificationStatus', isEqualTo: 'approved')
                .where('isFeatured', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 16),
                  itemCount: 3,
                  itemBuilder: (_, __) => const PropertyCardSkeleton(),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'No featured properties yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return _PropertyItem(data: data, propertyId: docs[index].id);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// RECENT SECTION
// ─────────────────────────────────────────

class _RecentSection extends StatelessWidget {
  const _RecentSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Recently Added',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('properties')
              .where('verificationStatus', isEqualTo: 'approved')
              .orderBy('createdAt', descending: true)
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Unable to load properties: ${snapshot.error}'),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: PropertyCardSkeleton(),
              );
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'No properties yet',
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data();
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: _PropertyItem(data: data, propertyId: docs[index].id),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// SHARED PROPERTY ITEM
// ─────────────────────────────────────────

class _PropertyItem extends StatelessWidget {
  final Map<String, dynamic> data;
  final String propertyId;

  const _PropertyItem({required this.data, required this.propertyId});

  @override
  Widget build(BuildContext context) {
    final images = (data['images'] as List? ?? [])
        .map((e) => e.toString())
        .toList();

    return PropertyCard(
      propertyId: propertyId,
      imageUrl: images.isNotEmpty ? images[0] : '',
      price: '₹${data['price']}',
      rawPrice: (data['price'] as num?)?.toInt(),
      title: data['title']?.toString() ?? '',
      location: data['city']?.toString() ?? '',
      bhk: '${data['bhk']} BHK',
      verified:
          (data['verificationStatus'] ?? '').toString().toLowerCase() ==
          'approved',
      areaSqft: (data['areaSqft'] as num?)?.toInt(),
      propertyCategory: data['propertyCategory']?.toString(),
      isFeatured: data['isFeatured'] == true,
      listingType: data['listingType']?.toString(),
      locality: data['locality']?.toString(),
      onTap: () {
        AppAnalyticsService.instance.logPropertyViewed(
          propertyId: propertyId,
          source: 'home',
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PropertyDetailsScreen(
              propertyId: propertyId,
              imageUrl: images.isNotEmpty ? images[0] : '',
              price: '₹${data['price']}',
              title: data['title']?.toString() ?? '',
              location: data['city']?.toString() ?? '',
              bhk: '${data['bhk']} BHK',
              brokerId: data['uploadedBy']?.toString() ?? '',
              imageUrls: images,
              verified: true,
            ),
          ),
        );
      },
    );
  }
}
