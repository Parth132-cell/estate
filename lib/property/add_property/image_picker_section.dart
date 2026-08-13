import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PropertyImageSelection {
  const PropertyImageSelection({
    required this.existingImageUrls,
    required this.newImages,
  });

  final List<String> existingImageUrls;
  final List<File> newImages;
}

class ImagePickerSection extends StatefulWidget {
  final ValueChanged<PropertyImageSelection> onChanged;
  final int maxImages;
  final List<String> initialImageUrls;

  const ImagePickerSection({
    super.key,
    required this.onChanged,
    this.maxImages = 10,
    this.initialImageUrls = const <String>[],
  });

  @override
  State<ImagePickerSection> createState() => _ImagePickerSectionState();
}

class _ImagePickerSectionState extends State<ImagePickerSection> {
  final ImagePicker _picker = ImagePicker();
  final List<File> _images = [];
  late final List<String> _existingImageUrls = [...widget.initialImageUrls];

  int get _totalImageCount => _existingImageUrls.length + _images.length;

  void _emitChange() {
    widget.onChanged(
      PropertyImageSelection(
        existingImageUrls: List<String>.unmodifiable(_existingImageUrls),
        newImages: List<File>.unmodifiable(_images),
      ),
    );
  }

  Future<void> _pickImages() async {
    try {
      final pickedFiles = await _picker.pickMultiImage(imageQuality: 75);

      if (pickedFiles.isEmpty) return;

      final availableSlots = widget.maxImages - _totalImageCount;
      if (availableSlots <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You can upload up to ${widget.maxImages} images'),
          ),
        );
        return;
      }

      final selected = pickedFiles
          .take(availableSlots)
          .map((x) => File(x.path))
          .toList();

      setState(() {
        _images.addAll(selected);
      });

      _emitChange();

      if (pickedFiles.length > selected.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Only ${widget.maxImages} images are allowed per listing',
            ),
          ),
        );
      }
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
    _emitChange();
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
    _emitChange();
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
        Text(
          'Add 3 to ${widget.maxImages} images',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._existingImageUrls.asMap().entries.map((entry) {
              final index = entry.key;
              final imageUrl = entry.value;

              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 90,
                        height: 90,
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.grey,
                        ),
                      ),
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
                      onPressed: () => _removeExistingImage(index),
                    ),
                  ),
                ],
              );
            }),

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
            if (_totalImageCount < widget.maxImages)
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
