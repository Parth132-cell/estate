import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class ImageUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<List<String>> uploadPropertyImages({
    required String propertyId,
    required List<File> images,
  }) async {
    List<String> urls = [];

    for (int i = 0; i < images.length; i++) {
      final ref = _storage.ref().child(
        'properties/$propertyId/img_${i + 1}.jpg',
      );

      await ref.putFile(images[i]);

      final url = await ref.getDownloadURL();
      urls.add(url);
    }

    return urls;
  }
}
