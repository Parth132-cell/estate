import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../colors.dart';
import '../navigation/main_navigation.dart';

/// Shows on first login when the user document has no name set.
/// Call this from AuthGate after ensureUserDocument() resolves and
/// the user's name is still empty.
///
/// Usage (in auth_gate or wherever you detect a new user):
///   if (snap.data['name'] == null || snap.data['name'].isEmpty) {
///     return const OnboardingScreen();
///   }
///   return const MainNavigation();
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _page = PageController();
  int _currentPage = 0;

  // Step 1 — role
  String _role = 'buyer'; // buyer | seller | broker

  // Step 2 — preferences
  final _cityController = TextEditingController();
  int? _selectedBhk;
  RangeValues _budget = const RangeValues(2000000, 10000000);

  // Step 3 — name
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _saving = false;

  @override
  void dispose() {
    _page.dispose();
    _cityController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < 2) {
      _page.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage++);
    }
  }

  void _back() {
    if (_currentPage > 0) {
      _page.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage--);
    }
  }

  Future<void> _finish() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'name': _nameController.text.trim(),
      'role': _role,
      'onboardingComplete': true,
      'preferences': {
        'city': _cityController.text.trim(),
        'bhk': _selectedBhk,
        'budgetMin': _budget.start.round(),
        'budgetMax': _budget.end.round(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigation()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Progress indicator ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: List.generate(3, (i) {
                  final active = i <= _currentPage;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.primary
                            : AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // ── Pages ──
            Expanded(
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _RolePage(
                    selected: _role,
                    onSelect: (r) => setState(() => _role = r),
                  ),
                  _PreferencesPage(
                    role: _role,
                    cityController: _cityController,
                    selectedBhk: _selectedBhk,
                    budget: _budget,
                    onBhkSelect: (b) => setState(() => _selectedBhk = b),
                    onBudgetChange: (r) => setState(() => _budget = r),
                  ),
                  _NamePage(
                    formKey: _formKey,
                    controller: _nameController,
                    role: _role,
                  ),
                ],
              ),
            ),

            // ── Navigation buttons ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: _back,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _saving
                          ? null
                          : _currentPage < 2
                          ? _next
                          : _finish,
                      style: AppButtons.primary,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _currentPage < 2 ? 'Continue' : 'Get Started',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// PAGE 1 — Role selection
// ─────────────────────────────────────────

class _RolePage extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _RolePage({required this.selected, required this.onSelect});

  static const _roles = [
    _RoleOption(
      key: 'buyer',
      icon: Icons.search_rounded,
      title: 'I\'m a Buyer',
      subtitle: 'Looking to buy or rent a property',
    ),
    _RoleOption(
      key: 'seller',
      icon: Icons.home_work_outlined,
      title: 'I\'m a Seller/Owner',
      subtitle: 'I want to list my property',
    ),
    _RoleOption(
      key: 'broker',
      icon: Icons.handshake_outlined,
      title: 'I\'m a Broker/Agent',
      subtitle: 'I manage deals and client relationships',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome to EstateX',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tell us who you are so we can personalise your experience.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          ..._roles.map(
            (r) => _RoleTile(
              option: r,
              isSelected: selected == r.key,
              onTap: () => onSelect(r.key),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleOption {
  final String key;
  final IconData icon;
  final String title;
  final String subtitle;
  const _RoleOption({
    required this.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _RoleTile extends StatelessWidget {
  final _RoleOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                option.icon,
                color: isSelected ? Colors.white : AppColors.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// PAGE 2 — Preferences
// ─────────────────────────────────────────

class _PreferencesPage extends StatelessWidget {
  final String role;
  final TextEditingController cityController;
  final int? selectedBhk;
  final RangeValues budget;
  final ValueChanged<int?> onBhkSelect;
  final ValueChanged<RangeValues> onBudgetChange;

  const _PreferencesPage({
    required this.role,
    required this.cityController,
    required this.selectedBhk,
    required this.budget,
    required this.onBhkSelect,
    required this.onBudgetChange,
  });

  String _formatBudget(double val) {
    if (val >= 10000000) return '₹${(val / 10000000).toStringAsFixed(1)}Cr';
    if (val >= 100000) return '₹${(val / 100000).toStringAsFixed(0)}L';
    return '₹${val.round()}';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _subtitle,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          // City — common to all roles
          const Text(
            'City / Area',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: cityController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: _cityHint,
              prefixIcon: const Icon(Icons.location_on_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Role-specific section
          if (role == 'buyer') ..._buyerFields(context),
          if (role == 'seller') ..._sellerFields(context),
          if (role == 'broker') ..._brokerFields(context),

          const SizedBox(height: 8),
          Text(
            'You can change these anytime in Settings.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  String get _title {
    switch (role) {
      case 'seller':
        return 'Tell us about your property';
      case 'broker':
        return 'Set up your broker profile';
      default:
        return 'What are you looking for?';
    }
  }

  String get _subtitle {
    switch (role) {
      case 'seller':
        return 'This helps us match your listing with the right buyers.';
      case 'broker':
        return 'This helps buyers and sellers find you on EstateX.';
      default:
        return 'We\'ll use this to show you the most relevant properties first.';
    }
  }

  String get _cityHint {
    switch (role) {
      case 'seller':
        return 'City where your property is located';
      case 'broker':
        return 'City / areas you operate in';
      default:
        return 'e.g. Ahmedabad, Mumbai, Pune';
    }
  }

  // ── BUYER ──────────────────────────────────
  List<Widget> _buyerFields(BuildContext context) {
    return [
      const Text(
        'BHK preference',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [null, 1, 2, 3, 4].map((bhk) {
          final label = bhk == null ? 'Any' : '$bhk BHK';
          final isSelected = selectedBhk == bhk;
          return Expanded(
            child: GestureDetector(
              onTap: () => onBhkSelect(bhk),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 24),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Budget range',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            '${_formatBudget(budget.start)} – ${_formatBudget(budget.end)}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      RangeSlider(
        values: budget,
        min: 500000,
        max: 50000000,
        divisions: 99,
        activeColor: AppColors.primary,
        inactiveColor: AppColors.primarySoft,
        onChanged: onBudgetChange,
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Text(
            '₹5L',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          Text(
            '₹5Cr',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    ];
  }

  // ── SELLER ──────────────────────────────────
  List<Widget> _sellerFields(BuildContext context) {
    return [
      const Text(
        'Property type',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: ['Apartment', 'House', 'Villa', 'Plot', 'Commercial']
            .map((type) => _Chip(label: type, selected: false, onTap: () {}))
            .toList(),
      ),
      const SizedBox(height: 24),
      const Text(
        'Listing goal',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 10),
      ...['Sell', 'Rent', 'Lease'].map(
        (goal) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _OptionTile(
            label: goal,
            icon: goal == 'Sell'
                ? Icons.monetization_on_outlined
                : goal == 'Rent'
                ? Icons.home_outlined
                : Icons.assignment_outlined,
          ),
        ),
      ),
    ];
  }

  // ── BROKER ──────────────────────────────────
  List<Widget> _brokerFields(BuildContext context) {
    return [
      const Text(
        'Specialisation',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          'Residential',
          'Commercial',
          'Luxury',
          'Plots',
          'Rental',
          'NRI properties',
        ].map((s) => _Chip(label: s, selected: false, onTap: () {})).toList(),
      ),
      const SizedBox(height: 24),
      const Text(
        'Years of experience',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: ['< 1 yr', '1–3 yrs', '3–7 yrs', '7+ yrs'].map((exp) {
          return Expanded(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  exp,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: const Row(
          children: [
            Icon(Icons.verified_outlined, color: AppColors.primary, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Complete your RERA registration in Profile after sign-up to get a Verified Broker badge.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.primary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  const _OptionTile({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
          const Spacer(),
          Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// PAGE 3 — Name
// ─────────────────────────────────────────

class _NamePage extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final String role;

  const _NamePage({
    required this.formKey,
    required this.controller,
    required this.role,
  });

  String get _roleLabel {
    switch (role) {
      case 'broker':
        return 'broker';
      case 'seller':
        return 'seller';
      default:
        return 'buyer';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Almost there!',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'What should we call you? Your name will appear on listings and deal communications.',
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 36),

            // Big avatar placeholder
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.person_outline,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 28),

            TextFormField(
              controller: controller,
              textCapitalization: TextCapitalization.words,
              autofocus: true,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Your full name',
                prefixIcon: const Icon(Icons.badge_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter your name';
                }
                if (v.trim().length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),
            Text(
              'Joining as a $_roleLabel — you can always update your role later in Profile.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}
