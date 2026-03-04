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

  void onImagesChanged(List<File> files) {
    images = files;
  }

  // Future<void> submit() async {
  //   if (!_formKey.currentState!.validate()) return;

  //   if (images.length < 3) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Please add at least 3 images')),
  //     );
  //     return;
  //   }

  //   setState(() => submitting = true);

  //   /// 🔧 TEMP SUBMIT PLACEHOLDER
  //   /// Backend integration comes later
  //   final service = PropertyService();

  //   await service.submitProperty(
  //     title: titleController.text.trim(),
  //     price: int.parse(priceController.text),
  //     city: cityController.text.trim(),
  //     bhk: bhk,
  //     listingType: widget.listingType,
  //     images: [], // image URLs will be added later
  //   );

  //   setState(() => submitting = false);

  //   if (!mounted) return;

  //   ScaffoldMessenger.of(context).showSnackBar(
  //     const SnackBar(content: Text('Property submitted for review')),
  //   );

  //   Navigator.pop(context);
  // }
  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (images.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least 3 images')),
      );
      return;
    }

    setState(() => submitting = true);

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
          /// 📸 Images
          ImagePickerSection(onChanged: onImagesChanged),

          const SizedBox(height: 24),

          /// 🏠 Title
          TextFormField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'Property title',
              hintText: 'e.g. 2 BHK Apartment',
            ),
            validator: (v) =>
                v == null || v.isEmpty ? 'Title is required' : null,
          ),

          const SizedBox(height: 16),

          /// 💰 Price
          TextFormField(
            controller: priceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Price (₹)'),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Price is required';
              if (double.tryParse(v) == null) return 'Enter valid amount';
              return null;
            },
          ),

          const SizedBox(height: 16),

          /// 📍 City
          TextFormField(
            controller: cityController,
            decoration: const InputDecoration(labelText: 'City'),
            validator: (v) =>
                v == null || v.isEmpty ? 'City is required' : null,
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

          /// 🛏 BHK
          const Text('BHK', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            children: [1, 2, 3, 4].map((b) {
              return ChoiceChip(
                label: Text('$b BHK'),
                selected: bhk == b,
                onSelected: (_) {
                  setState(() => bhk = b);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 32),

          /// 🚀 Submit
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
