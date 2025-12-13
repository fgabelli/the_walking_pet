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
