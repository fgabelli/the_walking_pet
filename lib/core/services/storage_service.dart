import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';


/// Storage service for Firebase Storage operations
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload user profile image
  Future<String> uploadUserProfileImage(String uid, File imageFile) async {
    try {
      print('Starting upload for user: $uid');
      print('Original file path: ${imageFile.path}');
      
      // Compress image
      final compressedFile = await _compressImage(imageFile);
      print('Compressed file path: ${compressedFile.path}');

      // Upload to Firebase Storage
      final ref = _storage.ref().child('users/$uid/profile.jpg');
      print('Uploading to: ${ref.fullPath}');
      
      final uploadTask = await ref.putFile(compressedFile);
      print('Upload state: ${uploadTask.state}');
      print('Bytes transferred: ${uploadTask.bytesTransferred}');

      // Get download URL
      final url = await uploadTask.ref.getDownloadURL();
      print('Download URL: $url');
      return url;
    } catch (e) {
      print('Error in uploadUserProfileImage: $e');
      rethrow;
    }
  }

  // Upload user cover image (Business)
  Future<String> uploadUserCoverImage(String uid, File imageFile) async {
    try {
      // Compress image (quality slightly lower or higher depending on need, but kept same for consistency)
      final compressedFile = await _compressImage(imageFile);

      // Upload to Firebase Storage
      final ref = _storage.ref().child('users/$uid/cover.jpg');
      
      final uploadTask = await ref.putFile(compressedFile);

      // Get download URL
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      rethrow;
    }
  }

  // Upload dog profile image
  Future<String> uploadDogProfileImage(String dogId, File imageFile) async {
    try {
      // Compress image
      final compressedFile = await _compressImage(imageFile);

      // Upload to Firebase Storage
      final ref = _storage.ref().child('dogs/$dogId/profile.jpg');
      final uploadTask = await ref.putFile(compressedFile);

      // Get download URL
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      rethrow;
    }
  }

  // Upload chat image
  Future<String> uploadChatImage(String chatId, File imageFile) async {
    try {
      // Compress image
      final compressedFile = await _compressImage(imageFile);

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = '$timestamp.jpg';

      // Upload to Firebase Storage
      final ref = _storage.ref().child('chats/$chatId/$filename');
      final uploadTask = await ref.putFile(compressedFile);

      // Get download URL
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      rethrow;
    }
  }

  // Upload announcement image
  Future<String> uploadAnnouncementImage(String announcementId, File imageFile) async {
    try {
      // Compress image
      final compressedFile = await _compressImage(imageFile);

      // Upload to Firebase Storage
      final ref = _storage.ref().child('announcements/$announcementId/image.jpg');
      final uploadTask = await ref.putFile(compressedFile);

      // Get download URL
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      rethrow;
    }
  }

  // Delete file by URL
  Future<void> deleteFileByUrl(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      rethrow;
    }
  }

  // Compress image
  Future<File> _compressImage(File file) async {
    try {
      final filePath = file.absolute.path;
      final lastIndex = filePath.lastIndexOf(RegExp(r'.jp'));
      final splitPath = filePath.substring(0, lastIndex);
      final outPath = '${splitPath}_compressed.jpg';

      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        filePath,
        outPath,
        quality: 85,
        minWidth: 1024,
        minHeight: 1024,
      );

      return File(compressedFile!.path);
    } catch (e) {
      // If compression fails, return original file
      return file;
    }
  }

  // Get file size
  Future<int> getFileSize(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      final metadata = await ref.getMetadata();
      return metadata.size ?? 0;
    } catch (e) {
      rethrow;
    }
  }
}
