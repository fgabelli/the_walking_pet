import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/reel_model.dart';

final reelServiceProvider = Provider<ReelService>((ref) => ReelService());

class ReelService {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  CollectionReference get _reelsCollection => _firestore.collection('reels');

  /// Get reels feed (all approved, newest first)
  Stream<List<ReelModel>> getReelsFeed() {
    return _reelsCollection
        .where('moderationStatus', isEqualTo: 'approved')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ReelModel.fromFirestore(d)).toList());
  }

  /// Get reels by a specific user
  Stream<List<ReelModel>> getUserReels(String userId) {
    return _reelsCollection
        .where('authorId', isEqualTo: userId)
        .where('moderationStatus', isEqualTo: 'approved')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ReelModel.fromFirestore(d)).toList());
  }

  /// Upload a reel video and create the document
  Future<String> createReel(ReelModel reel, File videoFile, {File? thumbnailFile}) async {
    // 1. Upload video to Firebase Storage
    final videoRef = _storage.ref().child('reels/${reel.authorId}/${DateTime.now().millisecondsSinceEpoch}.mp4');
    final uploadTask = await videoRef.putFile(videoFile, SettableMetadata(contentType: 'video/mp4'));
    final videoUrl = await uploadTask.ref.getDownloadURL();

    // 2. Upload thumbnail if provided
    String? thumbnailUrl;
    if (thumbnailFile != null) {
      final thumbRef = _storage.ref().child('reels/${reel.authorId}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg');
      final thumbUpload = await thumbRef.putFile(thumbnailFile, SettableMetadata(contentType: 'image/jpeg'));
      thumbnailUrl = await thumbUpload.ref.getDownloadURL();
    }

    // 3. Create Firestore document
    final reelData = ReelModel(
      id: '',
      authorId: reel.authorId,
      authorName: reel.authorName,
      authorPhotoUrl: reel.authorPhotoUrl,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      caption: reel.caption,
      durationMs: reel.durationMs,
      createdAt: DateTime.now(),
      moderationStatus: ModerationStatus.pending, // Cloud Function will approve/reject
    );

    final docRef = await _reelsCollection.add(reelData.toFirestore());
    return docRef.id;
  }

  /// Toggle like on a reel
  Future<void> toggleLike(String reelId, String userId) async {
    final doc = _reelsCollection.doc(reelId);
    final snap = await doc.get();
    if (!snap.exists) return;

    final likes = List<String>.from((snap.data() as Map<String, dynamic>)['likes'] ?? []);
    if (likes.contains(userId)) {
      likes.remove(userId);
    } else {
      likes.add(userId);
    }
    await doc.update({'likes': likes});
  }

  /// Increment view count
  Future<void> incrementView(String reelId) async {
    await _reelsCollection.doc(reelId).update({
      'viewCount': FieldValue.increment(1),
    });
  }

  /// Delete a reel
  Future<void> deleteReel(String reelId) async {
    final doc = await _reelsCollection.doc(reelId).get();
    if (!doc.exists) return;
    
    final data = doc.data() as Map<String, dynamic>;
    final videoUrl = data['videoUrl'] as String?;
    final thumbUrl = data['thumbnailUrl'] as String?;

    // Delete from storage
    if (videoUrl != null) {
      try { await _storage.refFromURL(videoUrl).delete(); } catch (_) {}
    }
    if (thumbUrl != null) {
      try { await _storage.refFromURL(thumbUrl).delete(); } catch (_) {}
    }

    await _reelsCollection.doc(reelId).delete();
  }

  /// Check reel upload permission (no daily limit)
  Future<bool> canUploadReel(String userId, bool isPremium) async {
    return true; // No daily limit for any user
  }

  /// Add comment to reel (reuses same comments subcollection pattern)
  Future<void> addComment(String reelId, Map<String, dynamic> commentData) async {
    await _reelsCollection.doc(reelId).collection('comments').add(commentData);
    await _reelsCollection.doc(reelId).update({
      'commentCount': FieldValue.increment(1),
    });
  }

  /// Get comments stream
  Stream<List<Map<String, dynamic>>> getCommentsStream(String reelId) {
    return _reelsCollection
        .doc(reelId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }
}
