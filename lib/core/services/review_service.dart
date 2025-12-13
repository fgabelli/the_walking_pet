import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/models/review_model.dart';
import '../../shared/models/user_model.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add a review for a Business Profile
  Future<void> addBusinessReview(ReviewModel review) async {
    if (review.targetUserId == null) throw Exception('Target User ID required for business review');

    final businessRef = _firestore.collection('users').doc(review.targetUserId);
    final reviewsRef = businessRef.collection('reviews');

    await _firestore.runTransaction((transaction) async {
      // 1. Get current business user data to check stats
      final businessDoc = await transaction.get(businessRef);
      if (!businessDoc.exists) throw Exception('Business user not found');

      final businessUser = UserModel.fromFirestore(businessDoc);
      
      // 2. Add the new review document
      // We use a new doc ID provided by the caller or auto-gen. 
      // If review.id is 'temp' or empty, we generate one, but ReviewModel expects an ID.
      // Usually we let Firestore gen ID. But here we have the object.
      // Let's assume we create a new ref with auto ID if the passed ID is empty.
      final newReviewRef = reviewsRef.doc(); 
      // We need to store the review with this new ID
      final reviewToSave = ReviewModel(
        id: newReviewRef.id,
        authorId: review.authorId,
        authorName: review.authorName,
        authorPhotoUrl: review.authorPhotoUrl,
        rating: review.rating,
        comment: review.comment,
        timestamp: DateTime.now(),
        targetUserId: review.targetUserId,
      );

      transaction.set(newReviewRef, reviewToSave.toFirestore());

      // 3. Update aggregations
      final currentCount = businessUser.reviewCount;
      final currentAvg = businessUser.averageRating;
      
      final newCount = currentCount + 1;
      final newAvg = ((currentAvg * currentCount) + review.rating) / newCount;

      transaction.update(businessRef, {
        'reviewCount': newCount,
        'averageRating': newAvg,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Get reviews stream for a business
  Stream<List<ReviewModel>> getBusinessReviews(String businessUserId) {
    return _firestore
        .collection('users')
        .doc(businessUserId)
        .collection('reviews')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ReviewModel.fromFirestore(doc)).toList();
    });
  }
  }

  // --- Announcement Reviews (Legacy/Nextdoor) ---

  // Add a review for an Announcement
  Future<void> addReview(ReviewModel review) async {
    // We store announcement reviews in a top-level 'reviews' collection
    // or we could store them in announcements/{id}/reviews.
    // Let's use top-level for flexibility if not defined otherwise.
    
    if (review.announcementId == null) throw Exception('Announcement ID required');
    
    // 1. Save Review to 'reviews' collection
    final docRef = _firestore.collection('reviews').doc();
    final reviewToSave = ReviewModel(
      id: docRef.id,
      authorId: review.authorId,
      authorName: review.authorName,
      authorPhotoUrl: review.authorPhotoUrl,
      announcementId: review.announcementId,
      rating: review.rating,
      comment: review.comment,
      timestamp: DateTime.now(),
      targetUserId: review.targetUserId,
    );
    await docRef.set(reviewToSave.toFirestore());

    // 2. Update User's average rating (The author of the announcement)
    // We need to know who the author of the announcement is.
    // This requires fetching the announcement or assuming the UI passes the targetUserId.
    // ReviewModel has `targetUserId`. If CreateReviewScreen sets it, we are good.
    // If not, we might fail to update the user stats.
    
    if (review.targetUserId != null) {
      await _updateUserRatingStats(review.targetUserId!, review.rating);
    }
  }

  Future<void> _updateUserRatingStats(String userId, double newRating) async {
    final userRef = _firestore.collection('users').doc(userId);
    
    await _firestore.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);
      if (!userDoc.exists) return; // Should not happen

      final user = UserModel.fromFirestore(userDoc);
      final currentCount = user.reviewCount;
      final currentAvg = user.averageRating;
      
      final newCount = currentCount + 1;
      final newAvg = ((currentAvg * currentCount) + newRating) / newCount;

      transaction.update(userRef, {
        'reviewCount': newCount,
        'averageRating': newAvg,
      });
    });
  }

  Stream<List<ReviewModel>> getReviewsForAnnouncement(String announcementId) {
    return _firestore
        .collection('reviews')
        .where('announcementId', isEqualTo: announcementId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ReviewModel.fromFirestore(doc)).toList();
    });
  }

  Future<bool> hasUserReviewedAnnouncement(String userId, String announcementId) async {
    final snapshot = await _firestore
        .collection('reviews')
        .where('authorId', isEqualTo: userId)
        .where('announcementId', isEqualTo: announcementId)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<double> getUserAverageRating(String userId) async {
    // Since we now store averageRating in UserModel, we just fetch that.
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return 0.0;
    final user = UserModel.fromFirestore(doc);
    return user.averageRating;
  }
}
