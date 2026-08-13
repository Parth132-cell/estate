import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:estatex_app/colors.dart';
import 'package:estatex_app/services/app_analytics_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ROLE SWITCH SCREEN
//
// Reachable from ProfileScreen via a "Manage Roles" tile.
// Lets any user add a secondary role without losing their primary one.
//
// Strategy:
//   - Firestore keeps a single `role` field (primary) for backwards compat.
//   - We add a `roles` list field that contains all active roles.
//   - All role-gating in profile_screen.dart already checks `role` — we
//     update that too, to the "most capable" role the user has.
//   - Broker role requires RERA number → goes to 'pending_broker' until admin
//     approves. All other role additions are instant.
// ─────────────────────────────────────────────────────────────────────────────

class RoleSwitchScreen extends StatefulWidget {
  const RoleSwitchScreen({super.key});

  @override
  State<RoleSwitchScreen> createState() => _RoleSwitchScreenState();
}

class _RoleSwitchScreenState extends State<RoleSwitchScreen> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Manage Roles'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data?.data() ?? {};
          final currentRole = (data['role'] ?? 'buyer').toString();
          final roles = List<String>.from(data['roles'] ?? [currentRole]);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'How roles work on EstateX',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You can hold multiple roles at once. Adding a role '
                      'unlocks new screens — your existing data is never lost. '
                      'You can switch your active view anytime.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text(
                'Your roles',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // Role cards
              _RoleCard(
                role: 'buyer',
                icon: Icons.search_rounded,
                title: 'Buyer',
                description:
                    'Search properties, make offers, schedule visits, use the negotiation assistant.',
                isActive: roles.contains('buyer'),
                isPrimary: currentRole == 'buyer',
                canRemove: roles.length > 1 && roles.contains('buyer'),
                pendingApproval: false,
                onAdd: () => _addRole(uid, roles, currentRole, 'buyer'),
                onSetPrimary: () => _setPrimaryRole(uid, data, roles, 'buyer'),
                onRemove: () =>
                    _removeRole(uid, data, roles, currentRole, 'buyer'),
              ),

              const SizedBox(height: 10),

              _RoleCard(
                role: 'seller',
                icon: Icons.home_work_outlined,
                title: 'Seller / Owner',
                description:
                    'List your properties, manage inquiries, track incoming offers, handle agreements.',
                isActive: roles.contains('seller'),
                isPrimary: currentRole == 'seller',
                canRemove: roles.length > 1 && roles.contains('seller'),
                pendingApproval: false,
                onAdd: () => _addRole(uid, roles, currentRole, 'seller'),
                onSetPrimary: () => _setPrimaryRole(uid, data, roles, 'seller'),
                onRemove: () =>
                    _removeRole(uid, data, roles, currentRole, 'seller'),
              ),

              const SizedBox(height: 10),

              _RoleCard(
                role: 'broker',
                icon: Icons.handshake_outlined,
                title: 'Broker / Agent',
                description:
                    'Full CRM, lead pipeline, co-brokerage, escrow management, live tours. Requires RERA registration.',
                isActive: roles.contains('broker'),
                isPrimary: currentRole == 'broker',
                canRemove: roles.length > 1 && roles.contains('broker'),
                pendingApproval:
                    (data['brokerApprovalStatus'] ?? '') == 'pending',
                onAdd: () => _requestBrokerRole(uid, data, roles, currentRole),
                onSetPrimary: () => _setPrimaryRole(uid, data, roles, 'broker'),
                onRemove: () =>
                    _removeRole(uid, data, roles, currentRole, 'broker'),
              ),

              const SizedBox(height: 32),

              // Active role switcher — only show if user has multiple roles
              if (roles.length > 1) ...[
                const Text(
                  'Active view',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Switch which role\'s screens and features you see right now.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                ...roles.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ActiveViewTile(
                      role: r,
                      isActive: currentRole == r,
                      onTap: () => _setPrimaryRole(uid, data, roles, r),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────────────

  Future<void> _addRole(
    String uid,
    List<String> roles,
    String currentRole,
    String newRole,
  ) async {
    if (roles.contains(newRole)) return;
    setState(() => _saving = true);

    try {
      final updatedRoles = [...roles, newRole];
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'roles': updatedRoles,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await AppAnalyticsService.instance.setCurrentUser(
        userId: uid,
        role: currentRole,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_roleLabel(newRole)} role added. You can switch views below.',
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _snackError('Failed to add role: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _requestBrokerRole(
    String uid,
    Map<String, dynamic> data,
    List<String> roles,
    String currentRole,
  ) async {
    if (roles.contains('broker')) return;

    final reraCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apply for Broker Role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Broker accounts require RERA registration verification. '
              'Your application will be reviewed within 24 hours.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reraCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'RERA Registration Number',
                hintText: 'e.g. RAA01234567890',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: AppButtons.primary,
            onPressed: () {
              if (reraCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Submit Application'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'roles': [...roles, 'broker'],
        'brokerApprovalStatus': 'pending',
        'reraNumber': reraCtrl.text.trim(),
        'brokerAppliedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create admin notification for review
      await FirebaseFirestore.instance.collection('admin_notifications').add({
        'type': 'broker_application',
        'userId': uid,
        'userName': data['name'] ?? '',
        'reraNumber': reraCtrl.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Application submitted — you\'ll be notified once approved.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _snackError('Failed to submit: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    reraCtrl.dispose();
  }

  Future<void> _setPrimaryRole(
    String uid,
    Map<String, dynamic> data,
    List<String> roles,
    String newPrimary,
  ) async {
    if (!roles.contains(newPrimary)) return;

    // Broker role: only switch if approved
    if (newPrimary == 'broker') {
      final status = (data['brokerApprovalStatus'] ?? '').toString();
      if (status == 'pending') {
        _snackError('Your broker application is pending admin approval.');
        return;
      }
      if (status != 'approved' && !roles.contains('broker')) {
        _snackError('Broker role not yet approved.');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'role': newPrimary,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Refresh analytics cache with new primary role
      await AppAnalyticsService.instance.setCurrentUser(
        userId: uid,
        role: newPrimary,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to ${_roleLabel(newPrimary)} view'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _snackError('Failed to switch role: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeRole(
    String uid,
    Map<String, dynamic> data,
    List<String> roles,
    String currentRole,
    String roleToRemove,
  ) async {
    if (roles.length <= 1) {
      _snackError('You must keep at least one role.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${_roleLabel(roleToRemove)} role?'),
        content: Text(
          'Your ${_roleLabel(roleToRemove).toLowerCase()} data (listings, offers, leads) '
          'will be preserved. You can re-add this role later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final updatedRoles = roles.where((r) => r != roleToRemove).toList();
      // If removing the primary role, auto-switch to first remaining role
      final newPrimary = currentRole == roleToRemove
          ? updatedRoles.first
          : currentRole;

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'roles': updatedRoles,
        'role': newPrimary,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await AppAnalyticsService.instance.setCurrentUser(
        userId: uid,
        role: newPrimary,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_roleLabel(roleToRemove)} role removed.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _snackError('Failed to remove role: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snackError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'seller':
        return 'Seller';
      case 'broker':
        return 'Broker';
      default:
        return 'Buyer';
    }
  }
}

// ─────────────────────────────────────────
// ROLE CARD
// ─────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  final String role;
  final IconData icon;
  final String title;
  final String description;
  final bool isActive;
  final bool isPrimary;
  final bool canRemove;
  final bool pendingApproval;
  final VoidCallback onAdd;
  final VoidCallback onSetPrimary;
  final VoidCallback onRemove;

  const _RoleCard({
    required this.role,
    required this.icon,
    required this.title,
    required this.description,
    required this.isActive,
    required this.isPrimary,
    required this.canRemove,
    required this.pendingApproval,
    required this.onAdd,
    required this.onSetPrimary,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primarySoft : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPrimary
              ? AppColors.primary
              : isActive
              ? AppColors.primary.withOpacity(0.3)
              : Colors.grey.shade200,
          width: isPrimary ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isActive ? Colors.white : Colors.grey.shade500,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? AppColors.textPrimary
                                : Colors.grey.shade500,
                          ),
                        ),
                        if (isPrimary) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Active view',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        if (pendingApproval) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Pending approval',
                              style: TextStyle(
                                color: Colors.amber.shade800,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: isActive ? AppColors.textSecondary : Colors.grey.shade400,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          // Actions
          Row(
            children: [
              if (!isActive) ...[
                Expanded(
                  child: ElevatedButton(
                    style: AppButtons.primary,
                    onPressed: onAdd,
                    child: Text('Add $title role'),
                  ),
                ),
              ] else ...[
                if (!isPrimary)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSetPrimary,
                      child: const Text('Switch to this view'),
                    ),
                  ),
                if (!isPrimary) const SizedBox(width: 8),
                if (canRemove)
                  IconButton(
                    onPressed: onRemove,
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red.shade400,
                    ),
                    tooltip: 'Remove $title role',
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// ACTIVE VIEW TILE
// ─────────────────────────────────────────

class _ActiveViewTile extends StatelessWidget {
  final String role;
  final bool isActive;
  final VoidCallback onTap;

  const _ActiveViewTile({
    required this.role,
    required this.isActive,
    required this.onTap,
  });

  static const _icons = {
    'buyer': Icons.search_rounded,
    'seller': Icons.home_work_outlined,
    'broker': Icons.handshake_outlined,
  };

  static const _labels = {
    'buyer': 'Buyer',
    'seller': 'Seller',
    'broker': 'Broker',
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isActive ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppColors.primary : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _icons[role] ?? Icons.person_outline,
              color: isActive ? Colors.white : AppColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              _labels[role] ?? role,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            if (isActive)
              const Icon(Icons.check_circle, color: Colors.white, size: 20)
            else
              const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
