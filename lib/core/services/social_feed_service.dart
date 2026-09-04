import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../shared/models/social_post_model.dart';
import 'analytics_service.dart';

final socialFeedServiceProvider = Provider<SocialFeedService>((ref) => SocialFeedService());

class SocialFeedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Get feed stream (all posts, most recent first)
  Stream<List<SocialPostModel>> getFeedStream({int limit = 50}) {
    return _firestore
        .collection('social_posts')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SocialPostModel.fromFirestore(doc)).toList());
  }

  /// Get user's posts stream
  Stream<List<SocialPostModel>> getUserPostsStream(String userId) {
    return _firestore
        .collection('social_posts')
        .where('authorId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => SocialPostModel.fromFirestore(doc)).toList());
  }

  /// Create a post
  Future<String> createPost(SocialPostModel post, {File? imageFile, File? videoFile}) async {
    String? imageUrl;

    // Upload image if provided
    if (imageFile != null) {
      final fileName = 'social_posts/${post.authorId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(fileName);
      await ref.putFile(imageFile);
      imageUrl = await ref.getDownloadURL();
    } else if (videoFile != null) {
      final fileName = 'social_posts/${post.authorId}/${DateTime.now().millisecondsSinceEpoch}.mp4';
      final ref = _storage.ref().child(fileName);
      await ref.putFile(videoFile, SettableMetadata(contentType: 'video/mp4'));
      imageUrl = await ref.getDownloadURL();
    }

    // Create post with image URL
    final postData = SocialPostModel(
      id: '',
      authorId: post.authorId,
      authorName: post.authorName,
      authorPhotoUrl: post.authorPhotoUrl,
      petName: post.petName,
      petPhotoUrl: post.petPhotoUrl,
      text: post.text,
      imageUrl: imageUrl ?? post.imageUrl,
      type: post.type,
      createdAt: post.createdAt,
    );

    final docRef = await _firestore.collection('social_posts').add(postData.toFirestore());
    await AnalyticsService.postPubblicato(tipo: postData.type.name);
    return docRef.id;
  }

  /// Toggle like on a post
  Future<void> toggleLike(String postId, String userId) async {
    final docRef = _firestore.collection('social_posts').doc(postId);
    final doc = await docRef.get();

    if (!doc.exists) return;

    final likes = List<String>.from((doc.data() as Map<String, dynamic>)['likes'] ?? []);

    if (likes.contains(userId)) {
      await docRef.update({
        'likes': FieldValue.arrayRemove([userId]),
      });
    } else {
      await docRef.update({
        'likes': FieldValue.arrayUnion([userId]),
      });
    }
  }

  /// Add comment to a post
  Future<void> addComment(String postId, PostCommentModel comment) async {
    await _firestore
        .collection('social_posts')
        .doc(postId)
        .collection('comments')
        .add(comment.toFirestore());

    // Increment comment count
    await _firestore.collection('social_posts').doc(postId).update({
      'commentCount': FieldValue.increment(1),
    });
  }

  /// Get comments for a post
  Stream<List<PostCommentModel>> getCommentsStream(String postId) {
    return _firestore
        .collection('social_posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => PostCommentModel.fromFirestore(doc)).toList());
  }

  /// Delete a post
  Future<void> deletePost(String postId) async {
    // Delete sub-collection comments first
    final comments = await _firestore
        .collection('social_posts')
        .doc(postId)
        .collection('comments')
        .get();
    for (final doc in comments.docs) {
      await doc.reference.delete();
    }
    await _firestore.collection('social_posts').doc(postId).delete();
  }

  /// Report a post for inappropriate content
  Future<void> reportPost({
    required String postId,
    required String reporterId,
    required String reporterName,
    required String reason,
    String? details,
  }) async {
    await _firestore.collection('content_reports').add({
      'postId': postId,
      'collection': 'social_posts',
      'reporterId': reporterId,
      'reporterName': reporterName,
      'reason': reason,
      'details': details,
      'status': 'pending', // pending, reviewed, dismissed
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Also increment report count on the post itself
    await _firestore.collection('social_posts').doc(postId).update({
      'reportCount': FieldValue.increment(1),
    });
  }

  /// Toggle bookmark on a post (save/unsave)
  Future<void> toggleBookmark(String postId, String userId) async {
    final userDoc = _firestore.collection('users').doc(userId);
    final snap = await userDoc.get();
    final bookmarks = List<String>.from((snap.data() as Map<String, dynamic>?)?['bookmarkedPosts'] ?? []);
    
    if (bookmarks.contains(postId)) {
      await userDoc.update({'bookmarkedPosts': FieldValue.arrayRemove([postId])});
    } else {
      await userDoc.update({'bookmarkedPosts': FieldValue.arrayUnion([postId])});
    }
  }

  /// Check if a post is bookmarked by user
  Future<bool> isBookmarked(String postId, String userId) async {
    final snap = await _firestore.collection('users').doc(userId).get();
    final bookmarks = List<String>.from((snap.data() as Map<String, dynamic>?)?['bookmarkedPosts'] ?? []);
    return bookmarks.contains(postId);
  }

  /// Stream of bookmarked post IDs for a user
  Stream<List<String>> bookmarkedPostIdsStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((snap) {
      return List<String>.from((snap.data() as Map<String, dynamic>?)?['bookmarkedPosts'] ?? []);
    });
  }
}
