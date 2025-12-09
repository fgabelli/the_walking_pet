import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/models/review_model.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'reviews';

  // Add a review for an announcement
  Future<void> addReview(ReviewModel review) async {
    try {
      await _firestore.collection(_collection).add(review.toFirestore());
    } catch (e) {
      rethrow;
    }
  }

  // Get reviews for a specific announcement
  Stream<List<ReviewModel>> getReviewsForAnnouncement(String announcementId) {
    return _firestore
        .collection(_collection)
        .where('announcementId', isEqualTo: announcementId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ReviewModel.fromFirestore(doc)).toList();
    });
  }

  // Get average rating for a specific announcement
  Future<double> getAverageRatingForAnnouncement(String announcementId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('announcementId', isEqualTo: announcementId)
          .get();

      if (snapshot.docs.isEmpty) return 0.0;

      final reviews = snapshot.docs.map((doc) => ReviewModel.fromFirestore(doc)).toList();
      final totalRating = reviews.fold<double>(0.0, (total, review) => total + review.rating);
      return totalRating / reviews.length;
    } catch (e) {
      return 0.0;
    }
  }

  // Get review count for a specific announcement
  Future<int> getReviewCountForAnnouncement(String announcementId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('announcementId', isEqualTo: announcementId)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // Get average rating for a user (from all their announcements)
  Future<double> getUserAverageRating(String userId) async {
    try {
      // First, get all announcements by this user
      final announcementsSnapshot = await _firestore
          .collection('announcements')
          .where('userId', isEqualTo: userId)
          .get();

      if (announcementsSnapshot.docs.isEmpty) return 0.0;

      final announcementIds = announcementsSnapshot.docs.map((doc) => doc.id).toList();

      // Get all reviews for these announcements
      final reviewsSnapshot = await _firestore
          .collection(_collection)
          .where('announcementId', whereIn: announcementIds)
          .get();

      if (reviewsSnapshot.docs.isEmpty) return 0.0;

      final reviews = reviewsSnapshot.docs.map((doc) => ReviewModel.fromFirestore(doc)).toList();
      final totalRating = reviews.fold<double>(0.0, (total, review) => total + review.rating);
      return totalRating / reviews.length;
    } catch (e) {
      return 0.0;
    }
  }

  // Check if current user has already reviewed an announcement
  Future<bool> hasUserReviewedAnnouncement(String authorId, String announcementId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('authorId', isEqualTo: authorId)
          .where('announcementId', isEqualTo: announcementId)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
