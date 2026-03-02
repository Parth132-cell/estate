import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerSection extends StatefulWidget {
  final Function(List<File>) onChanged;

  const ImagePickerSection({super.key, required this.onChanged});

  @override
  State<ImagePickerSection> createState() => _ImagePickerSectionState();
}

class _ImagePickerSectionState extends State<ImagePickerSection> {
  final ImagePicker _picker = ImagePicker();
  final List<File> _images = [];

  Future<void> _pickImages() async {
    try {
      final pickedFiles = await _picker.pickMultiImage(imageQuality: 75);

      if (pickedFiles.isEmpty) return;

      setState(() {
        _images.addAll(pickedFiles.map((x) => File(x.path)));
      });

      widget.onChanged(_images);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to pick images')));
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
    widget.onChanged(_images);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Property Images',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Add at least 3 images',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Existing images
            ..._images.asMap().entries.map((entry) {
              final index = entry.key;
              final file = entry.value;

              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      file,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: IconButton(
                      icon: const Icon(
                        Icons.cancel,
                        size: 20,
                        color: Colors.red,
                      ),
                      onPressed: () => _removeImage(index),
                    ),
                  ),
                ],
              );
            }),

            // Add button
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey),
                ),
                child: const Icon(Icons.add, size: 30, color: Colors.grey),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
