import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';

abstract class IStorageService {
  Future<String> uploadFile(File file, String path, {String? contentType});
  Future<String> uploadBytes(Uint8List bytes, String path, {String contentType = 'image/jpeg'});
  Future<void> deleteFile(String pathOrUrl);
}

class StorageService extends ChangeNotifier implements IStorageService {
  final FirebaseStorage _storage;

  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  @override
  Future<String> uploadFile(File file, String path, {String? contentType}) async {
    try {
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(
        contentType: contentType ?? _inferContentType(file.path),
      );
      final uploadTask = await ref.putFile(file, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      debugPrint('[StorageService] Successfully uploaded file to $path: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('[StorageService] Error uploading file to $path: $e');
      rethrow;
    }
  }

  @override
  Future<String> uploadBytes(Uint8List bytes, String path, {String contentType = 'image/jpeg'}) async {
    try {
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(contentType: contentType);
      final uploadTask = await ref.putData(bytes, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      debugPrint('[StorageService] Successfully uploaded bytes to $path: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('[StorageService] Error uploading bytes to $path: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteFile(String pathOrUrl) async {
    if (pathOrUrl.isEmpty) return;
    try {
      Reference ref;
      if (pathOrUrl.startsWith('gs://') || pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
        ref = _storage.refFromURL(pathOrUrl);
      } else {
        ref = _storage.ref().child(pathOrUrl);
      }
      await ref.delete();
      debugPrint('[StorageService] Successfully deleted file: $pathOrUrl');
    } catch (e) {
      debugPrint('[StorageService] Notice: Could not delete file $pathOrUrl: $e');
    }
  }

  String _inferContentType(String filePath) {
    final lower = filePath.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }
}
