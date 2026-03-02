import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class ImageUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<List<String>> uploadPropertyImages({
    required String propertyId,
    required List<File> images,
  }) async {
    if (images.isEmpty) {
      throw Exception('No images selected for upload');
    }

    final urls = <String>[];

    for (int i = 0; i < images.length; i++) {
      final image = images[i];
      if (!image.existsSync()) {
        throw Exception('Selected image not found: ${image.path}');
      }

      final ext = _safeExtension(image.path);
      final fileName =
          'img_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final ref = _storage.ref().child('properties/$propertyId/$fileName');

      try {
        await ref.putFile(
          image,
          SettableMetadata(contentType: 'image/$ext'),
        );

        final url = await ref.getDownloadURL();
        urls.add(url);
      } on FirebaseException catch (e) {
        throw Exception('Image upload failed at ${i + 1}/${images.length}: '
            '${e.code} ${e.message ?? ''}');
      }
    }

    return urls;
  }

  String _safeExtension(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpeg';
  }
}
