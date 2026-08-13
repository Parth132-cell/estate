import 'package:estatex_app/property/add_property/property_editor_form.dart';
import 'package:estatex_app/property/add_property/property_type_selector.dart';
import 'package:flutter/material.dart';

class SellerPropertyEditorScreen extends StatefulWidget {
  const SellerPropertyEditorScreen({
    super.key,
    required this.propertyId,
    required this.initialData,
  });

  final String propertyId;
  final Map<String, dynamic> initialData;

  @override
  State<SellerPropertyEditorScreen> createState() =>
      _SellerPropertyEditorScreenState();
}

class _SellerPropertyEditorScreenState
    extends State<SellerPropertyEditorScreen> {
  late String listingType = (widget.initialData['listingType'] ?? 'individual')
      .toString();

  @override
  Widget build(BuildContext context) {
    final verificationStatus = (widget.initialData['verificationStatus'] ?? '')
        .toString();
    final title = verificationStatus == 'rejected'
        ? 'Resubmit Property'
        : 'Edit Listing';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PropertyTypeSelector(
              // Change 'selected' to 'selectedCategory'
              selectedCategory: listingType,
              // Change 'onSelect' to 'onCategorySelect'
              onCategorySelect: (value) => setState(() => listingType = value),
            ),
            const SizedBox(height: 24),
            PropertyEditorForm(
              propertyId: widget.propertyId,
              listingType: listingType,
              initialData: widget.initialData,
              submitLabel: 'Save Changes',
            ),
          ],
        ),
      ),
    );
  }
}
