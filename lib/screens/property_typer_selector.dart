import 'package:estatex_app/colors.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PROPERTY CATEGORY — complete enum covering all EstateX listing types
// Matches what MagicBricks / 99Acres / NoBroker support
// ─────────────────────────────────────────────────────────────────────────────

enum PropertyCategory {
  // ── Residential ──────────────────────────────────────────────────────────
  apartment(
    'apartment',
    'Apartment',
    Icons.apartment_outlined,
    PropertyGroup.residential,
    true,
  ),
  house(
    'house',
    'House / Bungalow',
    Icons.home_outlined,
    PropertyGroup.residential,
    true,
  ),
  villa(
    'villa',
    'Villa',
    Icons.villa_outlined,
    PropertyGroup.residential,
    true,
  ),
  studio(
    'studio',
    'Studio / 1RK',
    Icons.single_bed_outlined,
    PropertyGroup.residential,
    false,
  ),
  builderFloor(
    'builder_floor',
    'Builder Floor',
    Icons.layers_outlined,
    PropertyGroup.residential,
    true,
  ),

  // ── Land & Plots ──────────────────────────────────────────────────────────
  residentialPlot(
    'residential_plot',
    'Residential Plot',
    Icons.landscape_outlined,
    PropertyGroup.land,
    false,
  ),
  commercialPlot(
    'commercial_plot',
    'Commercial Plot',
    Icons.store_mall_directory_outlined,
    PropertyGroup.land,
    false,
  ),
  agriculturalLand(
    'agricultural_land',
    'Agricultural Land',
    Icons.agriculture_outlined,
    PropertyGroup.land,
    false,
  ),
  farmHouse(
    'farm_house',
    'Farm House',
    Icons.cabin_outlined,
    PropertyGroup.land,
    false,
  ),

  // ── Commercial ────────────────────────────────────────────────────────────
  officeSpace(
    'office_space',
    'Office Space',
    Icons.business_center_outlined,
    PropertyGroup.commercial,
    false,
  ),
  retailShop(
    'retail_shop',
    'Retail / Shop',
    Icons.storefront_outlined,
    PropertyGroup.commercial,
    false,
  ),
  warehouse(
    'warehouse',
    'Warehouse / Godown',
    Icons.warehouse_outlined,
    PropertyGroup.commercial,
    false,
  ),
  coWorkingSpace(
    'co_working',
    'Co-working Space',
    Icons.workspaces_outlined,
    PropertyGroup.commercial,
    false,
  ),

  // ── Rental / PG ──────────────────────────────────────────────────────────
  flatRent(
    'flat_rent',
    'Flat for Rent',
    Icons.home_outlined,
    PropertyGroup.rental,
    true,
  ),
  pgHostel(
    'pg_hostel',
    'PG / Hostel',
    Icons.hotel_outlined,
    PropertyGroup.rental,
    false,
  ),
  coLiving(
    'co_living_space',
    'Co-living',
    Icons.people_outlined,
    PropertyGroup.rental,
    false,
  ),
  shortTermRental(
    'short_term_rental',
    'Short-term / Vacation',
    Icons.beach_access_outlined,
    PropertyGroup.rental,
    false,
  ),

  // ── New Projects ─────────────────────────────────────────────────────────
  newLaunch(
    'new_launch',
    'New Launch',
    Icons.rocket_launch_outlined,
    PropertyGroup.project,
    true,
  ),
  underConstruction(
    'under_construction',
    'Under Construction',
    Icons.construction_outlined,
    PropertyGroup.project,
    true,
  ),
  readyToMove(
    'ready_to_move',
    'Ready to Move',
    Icons.check_circle_outlined,
    PropertyGroup.project,
    true,
  );

  const PropertyCategory(
    this.key,
    this.label,
    this.icon,
    this.group,
    this.hasBhk,
  );

  final String key;
  final String label;
  final IconData icon;
  final PropertyGroup group;

  /// Whether BHK selector should show for this category
  final bool hasBhk;

  static PropertyCategory fromKey(String key) {
    return PropertyCategory.values.firstWhere(
      (c) => c.key == key,
      orElse: () => PropertyCategory.apartment,
    );
  }

  /// Whether this category is a rental listing (affects deal flow)
  bool get isRental => group == PropertyGroup.rental;

  /// Whether this category is a project listing (builder contact flow)
  bool get isProject => group == PropertyGroup.project;

  /// Whether this is land/plot (no BHK, area in sq yards)
  bool get isLand => group == PropertyGroup.land;
}

enum PropertyGroup {
  residential,
  land,
  commercial,
  rental,
  project;

  String get label {
    switch (this) {
      case PropertyGroup.residential:
        return 'Residential';
      case PropertyGroup.land:
        return 'Land & Plots';
      case PropertyGroup.commercial:
        return 'Commercial';
      case PropertyGroup.rental:
        return 'Rental / PG';
      case PropertyGroup.project:
        return 'New Projects';
    }
  }

  IconData get icon {
    switch (this) {
      case PropertyGroup.residential:
        return Icons.home_outlined;
      case PropertyGroup.land:
        return Icons.landscape_outlined;
      case PropertyGroup.commercial:
        return Icons.business_outlined;
      case PropertyGroup.rental:
        return Icons.hotel_outlined;
      case PropertyGroup.project:
        return Icons.rocket_launch_outlined;
    }
  }

  Color get color {
    switch (this) {
      case PropertyGroup.residential:
        return AppColors.primary;
      case PropertyGroup.land:
        return Colors.green.shade700;
      case PropertyGroup.commercial:
        return const Color(0xFF7C3AED);
      case PropertyGroup.rental:
        return Colors.orange.shade700;
      case PropertyGroup.project:
        return Colors.teal.shade700;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROPERTY TYPE SELECTOR WIDGET
// Shows categories grouped by PropertyGroup with expandable sections
// ─────────────────────────────────────────────────────────────────────────────

class PropertyTypeSelector extends StatefulWidget {
  final String selectedCategory;
  final ValueChanged<String> onCategorySelect;

  const PropertyTypeSelector({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelect,
  });

  @override
  State<PropertyTypeSelector> createState() => _PropertyTypeSelectorState();
}

class _PropertyTypeSelectorState extends State<PropertyTypeSelector> {
  // Which groups are expanded — residential is open by default
  final Set<PropertyGroup> _expanded = {PropertyGroup.residential};

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Property category',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Select the type that best describes your property.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),

        // Group sections
        ...PropertyGroup.values.map((group) {
          final cats = PropertyCategory.values
              .where((c) => c.group == group)
              .toList();
          final isExpanded = _expanded.contains(group);
          final hasSelection = cats.any(
            (c) => c.key == widget.selectedCategory,
          );

          return Column(
            children: [
              // Group header
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expanded.remove(group);
                    } else {
                      _expanded.add(group);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: hasSelection
                        ? group.color.withOpacity(0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: hasSelection
                          ? group.color.withOpacity(0.4)
                          : Colors.grey.shade200,
                      width: hasSelection ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: group.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(group.icon, color: group.color, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        group.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: hasSelection
                              ? group.color
                              : AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      if (hasSelection)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: group.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            PropertyCategory.fromKey(
                              widget.selectedCategory,
                            ).label,
                            style: TextStyle(
                              fontSize: 11,
                              color: group.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

              // Category chips — shown when expanded
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: cats.map((cat) {
                      final isSelected = widget.selectedCategory == cat.key;
                      return GestureDetector(
                        onTap: () => widget.onCategorySelect(cat.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? group.color : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? group.color
                                  : Colors.grey.shade200,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: group.color.withOpacity(0.2),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                cat.icon,
                                size: 16,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cat.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),

              const SizedBox(height: 8),
            ],
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPLORE CATEGORY FILTER
// Horizontal scrollable filter chips for explore screen
// ─────────────────────────────────────────────────────────────────────────────

class ExploreCategoryFilter extends StatelessWidget {
  final String? selectedCategory;
  final ValueChanged<String?> onSelect;

  const ExploreCategoryFilter({
    super.key,
    required this.selectedCategory,
    required this.onSelect,
  });

  static const _quickFilters = [
    ('apartment', 'Apartments', Icons.apartment_outlined),
    ('house', 'Houses', Icons.home_outlined),
    ('villa', 'Villas', Icons.villa_outlined),
    ('residential_plot', 'Plots', Icons.landscape_outlined),
    ('agricultural_land', 'Land', Icons.agriculture_outlined),
    ('office_space', 'Offices', Icons.business_center_outlined),
    ('retail_shop', 'Shops', Icons.storefront_outlined),
    ('pg_hostel', 'PG / Hostel', Icons.hotel_outlined),
    ('flat_rent', 'Rental', Icons.home_outlined),
    ('new_launch', 'New Launch', Icons.rocket_launch_outlined),
    ('under_construction', 'Under Const.', Icons.construction_outlined),
    ('warehouse', 'Warehouse', Icons.warehouse_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // All
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _FilterChip(
              label: 'All',
              icon: Icons.apps_outlined,
              selected: selectedCategory == null,
              onTap: () => onSelect(null),
              color: AppColors.primary,
            ),
          ),
          ..._quickFilters.map((f) {
            final (key, label, icon) = f;
            final cat = PropertyCategory.fromKey(key);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _FilterChip(
                label: label,
                icon: icon,
                selected: selectedCategory == key,
                onTap: () => onSelect(key),
                color: cat.group.color,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? color : Colors.grey.shade200,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
