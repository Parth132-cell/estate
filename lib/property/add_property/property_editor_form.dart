import 'dart:io';

import 'package:estatex_app/services/property_services.dart';
import 'package:flutter/material.dart';

import 'image_picker_section.dart';

class PropertyEditorForm extends StatefulWidget {
  const PropertyEditorForm({
    super.key,
    required this.listingType,
    this.propertyCategory = 'apartment',
    this.propertyId,
    this.initialData,
    this.submitLabel = 'Submit Property',
  });

  final String listingType;
  final String propertyCategory;
  final String? propertyId;
  final Map<String, dynamic>? initialData;
  final String submitLabel;

  @override
  State<PropertyEditorForm> createState() => _PropertyEditorFormState();
}

class _PropertyEditorFormState extends State<PropertyEditorForm> {
  final _formKey = GlobalKey<FormState>();

  final titleController = TextEditingController();
  final priceController = TextEditingController();
  final cityController = TextEditingController();
  final localityController = TextEditingController();
  final latitudeController = TextEditingController();
  final longitudeController = TextEditingController();
  final areaController = TextEditingController();
  final descriptionController = TextEditingController();

  int bhk = 2;
  List<File> newImages = <File>[];
  List<String> existingImageUrls = <String>[];
  bool submitting = false;
  double uploadProgress = 0;
  String? lastError;

  bool get _isEditing => widget.propertyId != null;

  /// BHK only applies to residential categories
  bool get _showBhk =>
      const {'apartment', 'house', 'villa'}.contains(widget.propertyCategory);

  /// Area label changes based on category
  String get _areaLabel {
    switch (widget.propertyCategory) {
      case 'plot':
      case 'land':
        return 'Plot area (sq yards)';
      case 'commercial':
      case 'warehouse':
        return 'Carpet area (sq ft)';
      default:
        return 'Built-up area (sq ft)';
    }
  }

  /// Price label
  String get _priceLabel {
    switch (widget.propertyCategory) {
      case 'plot':
      case 'land':
        return 'Total price (INR)';
      default:
        return 'Price (INR)';
    }
  }

  @override
  void initState() {
    super.initState();
    final data = widget.initialData ?? const <String, dynamic>{};

    titleController.text = (data['title'] ?? '').toString();
    final price = (data['price'] as num?)?.toInt();
    priceController.text = price == null || price == 0 ? '' : '$price';
    cityController.text = (data['city'] ?? '').toString();
    localityController.text = (data['locality'] ?? '').toString();

    final latitude = data['latitude'];
    if (latitude is num) {
      latitudeController.text = latitude.toString();
    }

    final longitude = data['longitude'];
    if (longitude is num) {
      longitudeController.text = longitude.toString();
    }

    final areaSqft = (data['areaSqft'] as num?)?.toInt();
    areaController.text = areaSqft == null ? '' : '$areaSqft';
    descriptionController.text = (data['description'] ?? '').toString();
    bhk = ((data['bhk'] as num?)?.toInt() ?? 2).clamp(1, 20);
    existingImageUrls = ((data['images'] as List?) ?? const [])
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList(growable: true);
  }

  void onImagesChanged(PropertyImageSelection selection) {
    setState(() {
      newImages = selection.newImages;
      existingImageUrls = selection.existingImageUrls;
    });
  }

  Future<void> submit({required bool saveAsDraft}) async {
    if (!_formKey.currentState!.validate()) return;

    final totalImages = existingImageUrls.length + newImages.length;
    if (!saveAsDraft && (totalImages < 3 || totalImages > 10)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add between 3 and 10 images')),
      );
      return;
    }

    setState(() {
      submitting = true;
      uploadProgress = 0;
      lastError = null;
    });

    try {
      final service = PropertyService();
      final input = PropertyUpsertInput(
        title: titleController.text.trim(),
        price: int.tryParse(priceController.text.trim()),
        city: cityController.text.trim(),
        locality: localityController.text.trim(),
        latitude: double.tryParse(latitudeController.text.trim()),
        longitude: double.tryParse(longitudeController.text.trim()),
        areaSqft: int.tryParse(areaController.text.trim()),
        description: descriptionController.text.trim(),
        bhk: _showBhk ? bhk : 0,
        listingType: widget.listingType,
        propertyCategory: widget.propertyCategory,
        existingImageUrls: existingImageUrls,
        newImages: newImages,
      );

      final initialVerificationStatus =
          (widget.initialData?['verificationStatus'] ?? '').toString();

      if (saveAsDraft) {
        await service.saveDraft(
          propertyId: widget.propertyId,
          input: input,
          onUploadProgress: _updateProgress,
        );
      } else if (_isEditing && initialVerificationStatus == 'rejected') {
        await service.resubmitRejectedProperty(
          propertyId: widget.propertyId!,
          input: input,
          onUploadProgress: _updateProgress,
        );
      } else if (_isEditing) {
        await service.updateListing(
          propertyId: widget.propertyId!,
          input: input,
          onUploadProgress: _updateProgress,
        );
      } else {
        await service.submitProperty(
          input: input,
          onUploadProgress: _updateProgress,
        );
      }

      if (!mounted) return;

      final successText = saveAsDraft
          ? 'Draft saved successfully'
          : initialVerificationStatus == 'rejected'
          ? 'Property resubmitted successfully'
          : _isEditing
          ? 'Property updated successfully'
          : 'Property submitted successfully';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successText)));
      Navigator.pop(context, true);
    } catch (e) {
      final message = e.toString().toLowerCase().contains('unauthorized')
          ? 'Upload failed: Storage permission denied. Please check Firebase Storage rules for authenticated users.'
          : saveAsDraft
          ? 'Failed to save draft: $e'
          : 'Failed to submit property: $e';
      if (!mounted) return;
      setState(() {
        lastError = message;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => submitting = false);
      }
    }
  }

  void _updateProgress(double progress) {
    if (!mounted) return;
    setState(() => uploadProgress = progress);
  }

  String get _primaryButtonLabel {
    final verificationStatus = (widget.initialData?['verificationStatus'] ?? '')
        .toString();
    if (_isEditing && verificationStatus == 'rejected') {
      return 'Resubmit for Review';
    }
    return widget.submitLabel;
  }

  @override
  void dispose() {
    titleController.dispose();
    priceController.dispose();
    cityController.dispose();
    localityController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    areaController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ImagePickerSection(
            onChanged: onImagesChanged,
            maxImages: 10,
            initialImageUrls: existingImageUrls,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'Property title',
              hintText: 'e.g. 2 BHK Apartment',
            ),
            validator: (v) {
              final value = (v ?? '').trim();
              if (value.isEmpty) return null;
              if (value.length < 3)
                return 'Title must be at least 3 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: priceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: _priceLabel),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              final parsed = int.tryParse(v);
              if (parsed == null || parsed <= 0) return 'Enter valid amount';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: cityController,
            decoration: const InputDecoration(labelText: 'City'),
            validator: (v) {
              final value = (v ?? '').trim();
              if (value.isEmpty) return null;
              if (value.length < 2) return 'City is too short';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: localityController,
            decoration: const InputDecoration(labelText: 'Locality / Area'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: latitudeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Latitude (optional)',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final parsed = double.tryParse(v.trim());
                    if (parsed == null || parsed < -90 || parsed > 90) {
                      return 'Invalid latitude';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: longitudeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Longitude (optional)',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final parsed = double.tryParse(v.trim());
                    if (parsed == null || parsed < -180 || parsed > 180) {
                      return 'Invalid longitude';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Add coordinates for precise map pins. Older listings without coordinates will still appear with approximate city placement.',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: areaController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: _areaLabel),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              final area = int.tryParse(v.trim());
              if (area == null || area <= 0) return 'Enter valid area';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: descriptionController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Tell buyers about amenities, facing, furnishing, etc.',
            ),
          ),
          const SizedBox(height: 20),
          if (_showBhk) ...[
            const Text('BHK', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [1, 2, 3, 4, 5].map((value) {
                return ChoiceChip(
                  label: Text('$value BHK'),
                  selected: bhk == value,
                  onSelected: (_) {
                    setState(() => bhk = value);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ] else
            const SizedBox(height: 24),
          if (submitting)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: uploadProgress == 0 ? null : uploadProgress,
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload progress: ${(uploadProgress * 100).toStringAsFixed(0)}%',
                ),
              ],
            ),
          if (lastError != null) ...[
            const SizedBox(height: 12),
            Text(lastError!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: submitting ? null : () => submit(saveAsDraft: false),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry failed upload'),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: submitting
                      ? null
                      : () => submit(saveAsDraft: true),
                  child: const Text('Save Draft'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () => submit(saveAsDraft: false),
                  child: submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_primaryButtonLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
