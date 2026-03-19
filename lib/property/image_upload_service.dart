import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<List<String>> uploadPropertyImages({
    required String propertyId,
    required List<File> images,
    required void Function(double progress) onProgress,
    int maxRetries = 2,
  }) async {
    if (images.isEmpty) {
      throw Exception('No images selected for upload');
    }

    if (images.length > 10) {
      throw Exception('You can upload a maximum of 10 images');
    }

    final urls = <String>[];

    for (int i = 0; i < images.length; i++) {
      final image = images[i];
      if (!image.existsSync()) {
        throw Exception('Selected image not found: ${image.path}');
      }

      final compressedFile = await _compressImage(image);
      final ext = _safeExtension(compressedFile.path);
      final fileName = 'img_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final ref = _storage.ref().child('properties/$propertyId/$fileName');

      var attempt = 0;
      while (true) {
        try {
          await ref.putFile(
            compressedFile,
            SettableMetadata(contentType: 'image/$ext'),
          );

          final url = await ref.getDownloadURL();
          urls.add(url);
          onProgress(urls.length / images.length);
          break;
        } on FirebaseException catch (e) {
          if (attempt >= maxRetries) {
            throw Exception(
              'Image upload failed at ${i + 1}/${images.length}: '
              '${e.code} ${e.message ?? ''}',
            );
          }
          attempt++;
          await Future.delayed(Duration(milliseconds: 400 * attempt));
        }
      }
    }

    return urls;
  }

  Future<File> _compressImage(File source) async {
    final targetPath = '${source.path}_compressed.jpg';
    final result = await FlutterImageCompress.compressAndGetFile(
      source.path,
      targetPath,
      quality: 75,
      minWidth: 1280,
      minHeight: 720,
      format: CompressFormat.jpeg,
    );

    if (result == null) {
      return source;
    }

    return File(result.path);
  }

  String _safeExtension(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpeg';
  }
}
