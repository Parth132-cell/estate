import 'dart:io';

import 'package:estatex_app/services/property_services.dart';
import 'package:flutter/material.dart';

import 'image_picker_section.dart';

class PropertyForm extends StatefulWidget {
  final String listingType; // individual | professional

  const PropertyForm({super.key, required this.listingType});

  @override
  State<PropertyForm> createState() => _PropertyFormState();
}

class _PropertyFormState extends State<PropertyForm> {
  final _formKey = GlobalKey<FormState>();

  final titleController = TextEditingController();
  final priceController = TextEditingController();
  final cityController = TextEditingController();
  final localityController = TextEditingController();
  final areaController = TextEditingController();
  final descriptionController = TextEditingController();

  int bhk = 2;
  List<File> images = [];
  bool submitting = false;
  double uploadProgress = 0;
  String? lastError;

  void onImagesChanged(List<File> files) {
    setState(() {
      images = files;
    });
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (images.length < 3 || images.length > 10) {
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
      await PropertyService().submitProperty(
        title: titleController.text.trim(),
        price: int.parse(priceController.text),
        city: cityController.text.trim(),
        locality: localityController.text.trim(),
        areaSqft: int.tryParse(areaController.text.trim()),
        description: descriptionController.text.trim(),
        bhk: bhk,
        listingType: widget.listingType,
        images: images,
        onUploadProgress: (progress) {
          if (!mounted) return;
          setState(() => uploadProgress = progress);
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Property submitted successfully')),
      );

      Navigator.pop(context);
    } catch (e) {
      final message = e.toString().toLowerCase().contains('unauthorized')
          ? 'Upload failed: Storage permission denied. Please check Firebase Storage rules for authenticated users.'
          : 'Failed to submit property: $e';
      if (!mounted) return;
      setState(() {
        lastError = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => submitting = false);
      }
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    priceController.dispose();
    cityController.dispose();
    localityController.dispose();
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
          ImagePickerSection(onChanged: onImagesChanged, maxImages: 10),

          const SizedBox(height: 24),

          TextFormField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'Property title',
              hintText: 'e.g. 2 BHK Apartment',
            ),
            validator: (v) {
              final value = (v ?? '').trim();
              if (value.isEmpty) return 'Title is required';
              if (value.length < 3) return 'Title must be at least 3 characters';
              return null;
            },
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller: priceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Price (₹)'),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Price is required';
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
              if (value.isEmpty) return 'City is required';
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

          TextFormField(
            controller: areaController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Built-up area (sq ft)'),
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

          const Text('BHK', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            children: [1, 2, 3, 4, 5].map((b) {
              return ChoiceChip(
                label: Text('$b BHK'),
                selected: bhk == b,
                onSelected: (_) {
                  setState(() => bhk = b);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          if (submitting)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(value: uploadProgress == 0 ? null : uploadProgress),
                const SizedBox(height: 8),
                Text('Upload progress: ${(uploadProgress * 100).toStringAsFixed(0)}%'),
              ],
            ),

          if (lastError != null) ...[
            const SizedBox(height: 12),
            Text(lastError!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: submitting ? null : submit,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry failed upload'),
            ),
          ],

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: submitting ? null : submit,
              child: submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit Property'),
            ),
          ),
        ],
      ),
    );
  }
}
