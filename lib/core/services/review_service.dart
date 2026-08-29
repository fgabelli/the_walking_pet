import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/review_model.dart';
import '../../shared/models/user_model.dart';
import 'content_moderation_service.dart';

/// Provider
final reviewServiceProvider = Provider<ReviewService>((ref) {
  return ReviewService();
});

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================
  // PET BUSINESS / DOG PARK REVIEWS (NEW)
  // ============================================

  /// Collection path: pet_businesses/{businessId}/reviews
  CollectionReference _petBusinessReviews(String businessId) {
    return _firestore
        .collection('pet_businesses')
        .doc(businessId)
        .collection('reviews');
  }

  /// Submit a review for a pet business/dog park with content moderation
  Future<ReviewSubmitResult> submitPetBusinessReview({
    required String businessId,
    required String authorId,
    required String authorName,
    String? authorPhotoUrl,
    required double rating,
    required String comment,
  }) async {
    // 1. Validate rating
    if (rating < 1 || rating > 5) {
      return ReviewSubmitResult(
        success: false,
        message: 'Seleziona una valutazione da 1 a 5 stelle.',
      );
    }

    // 2. Content moderation check
    final moderationResult = ContentModerationService.moderateText(comment);
    if (!moderationResult.isClean) {
      return ReviewSubmitResult(
        success: false,
        message: moderationResult.reason ?? 'Contenuto non appropriato.',
        moderationFailed: true,
      );
    }

    // 3. Check if user already reviewed this business
    final existingReview = await _petBusinessReviews(businessId)
        .where('authorId', isEqualTo: authorId)
        .limit(1)
        .get();

    if (existingReview.docs.isNotEmpty) {
      return ReviewSubmitResult(
        success: false,
        message: 'Hai già lasciato una recensione. Puoi modificarla.',
        existingReviewId: existingReview.docs.first.id,
      );
    }

    // 4. Create the review
    final review = ReviewModel(
      id: '',
      authorId: authorId,
      authorName: authorName,
      authorPhotoUrl: authorPhotoUrl,
      businessId: businessId,
      rating: rating,
      comment: comment.trim(),
      timestamp: DateTime.now(),
      moderationStatus: ModerationStatus.approved,
    );

    try {
      final docRef = await _petBusinessReviews(businessId).add(review.toFirestore());
      await _updatePetBusinessRating(businessId);

      return ReviewSubmitResult(
        success: true,
        message: 'Recensione pubblicata con successo!',
        reviewId: docRef.id,
      );
    } catch (e) {
      return ReviewSubmitResult(
        success: false,
        message: 'Errore durante la pubblicazione. Riprova.',
      );
    }
  }

  /// Update an existing pet business review
  Future<ReviewSubmitResult> updatePetBusinessReview({
    required String businessId,
    required String reviewId,
    required String authorId,
    required double rating,
    required String comment,
  }) async {
    final moderationResult = ContentModerationService.moderateText(comment);
    if (!moderationResult.isClean) {
      return ReviewSubmitResult(
        success: false,
        message: moderationResult.reason ?? 'Contenuto non appropriato.',
        moderationFailed: true,
      );
    }

    try {
      final doc = await _petBusinessReviews(businessId).doc(reviewId).get();
      if (!doc.exists) {
        return ReviewSubmitResult(success: false, message: 'Recensione non trovata.');
      }
      final existing = ReviewModel.fromFirestore(doc);
      if (existing.authorId != authorId) {
        return ReviewSubmitResult(success: false, message: 'Non puoi modificare questa recensione.');
      }

      await _petBusinessReviews(businessId).doc(reviewId).update({
        'rating': rating,
        'comment': comment.trim(),
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'moderationStatus': ModerationStatus.approved.name,
        'reportCount': 0,
        'reportedByUserIds': [],
      });

      await _updatePetBusinessRating(businessId);

      return ReviewSubmitResult(
        success: true,
        message: 'Recensione aggiornata!',
        reviewId: reviewId,
      );
    } catch (e) {
      return ReviewSubmitResult(success: false, message: 'Errore: $e');
    }
  }

  /// Delete a pet business review
  Future<bool> deletePetBusinessReview({
    required String businessId,
    required String reviewId,
    required String requestingUserId,
  }) async {
    try {
      final doc = await _petBusinessReviews(businessId).doc(reviewId).get();
      if (!doc.exists) return false;

      final review = ReviewModel.fromFirestore(doc);
      if (review.authorId != requestingUserId) return false;

      await _petBusinessReviews(businessId).doc(reviewId).delete();
      await _updatePetBusinessRating(businessId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Stream of approved reviews for a pet business (most recent first)
  Stream<List<ReviewModel>> getPetBusinessReviewsStream(String businessId) {
    return _petBusinessReviews(businessId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReviewModel.fromFirestore(doc))
            .where((r) => r.isVisible)
            .toList());
  }

  /// Get review stats for a pet business
  Future<ReviewStats> getPetBusinessReviewStats(String businessId) async {
    final snapshot = await _petBusinessReviews(businessId)
        .where('moderationStatus', isEqualTo: 'approved')
        .get();

    if (snapshot.docs.isEmpty) {
      return ReviewStats(averageRating: 0, totalReviews: 0, distribution: {});
    }

    final reviews = snapshot.docs.map((d) => ReviewModel.fromFirestore(d)).toList();
    final total = reviews.length;
    final avg = reviews.map((r) => r.rating).reduce((a, b) => a + b) / total;

    final dist = <int, int>{};
    for (var i = 1; i <= 5; i++) {
      dist[i] = reviews.where((r) => r.rating.round() == i).length;
    }

    return ReviewStats(averageRating: avg, totalReviews: total, distribution: dist);
  }

  /// Report a review as inappropriate
  Future<ReviewSubmitResult> reportReview({
    required String businessId,
    required String reviewId,
    required String reportingUserId,
  }) async {
    try {
      final doc = await _petBusinessReviews(businessId).doc(reviewId).get();
      if (!doc.exists) {
        return ReviewSubmitResult(success: false, message: 'Recensione non trovata.');
      }

      final review = ReviewModel.fromFirestore(doc);

      if (review.reportedByUserIds.contains(reportingUserId)) {
        return ReviewSubmitResult(
          success: false,
          message: 'Hai già segnalato questa recensione.',
        );
      }

      final newReportCount = review.reportCount + 1;
      final newReportedBy = [...review.reportedByUserIds, reportingUserId];

      // Auto-flag at 3 reports, auto-reject at 5
      ModerationStatus newStatus = review.moderationStatus;
      String? note;
      if (newReportCount >= 5) {
        newStatus = ModerationStatus.rejected;
        note = 'Rimosso automaticamente per troppe segnalazioni.';
      } else if (newReportCount >= 3) {
        newStatus = ModerationStatus.flagged;
      }

      await _petBusinessReviews(businessId).doc(reviewId).update({
        'reportCount': newReportCount,
        'reportedByUserIds': newReportedBy,
        'moderationStatus': newStatus.name,
        if (note != null) 'moderationNote': note,
      });

      return ReviewSubmitResult(
        success: true,
        message: 'Segnalazione inviata. Grazie per il tuo contributo.',
      );
    } catch (e) {
      return ReviewSubmitResult(success: false, message: 'Errore durante la segnalazione.');
    }
  }

  /// Update aggregate rating on pet business document
  Future<void> _updatePetBusinessRating(String businessId) async {
    try {
      final snapshot = await _petBusinessReviews(businessId)
          .where('moderationStatus', isEqualTo: 'approved')
          .get();

      if (snapshot.docs.isEmpty) {
        await _firestore.collection('pet_businesses').doc(businessId).update({
          'rating': null,
          'userRatingsTotal': 0,
        });
        return;
      }

      final ratings = snapshot.docs
          .map((d) => (d.data() as Map<String, dynamic>)['rating'] as num)
          .toList();

      final avg = ratings.reduce((a, b) => a + b) / ratings.length;

      await _firestore.collection('pet_businesses').doc(businessId).update({
        'rating': double.parse(avg.toStringAsFixed(1)),
        'userRatingsTotal': ratings.length,
      });
    } catch (e) {
      print('Error updating pet business rating: $e');
    }
  }

  // ============================================
  // EXISTING: BUSINESS PROFILE (USER) REVIEWS
  // ============================================

  /// Add review for a Business Profile (user-based)
  Future<void> addBusinessReview(ReviewModel review) async {
    if (review.targetUserId == null) throw Exception('Target User ID required for business review');

    final businessRef = _firestore.collection('users').doc(review.targetUserId);
    final reviewsRef = businessRef.collection('reviews');

    await _firestore.runTransaction((transaction) async {
      final businessDoc = await transaction.get(businessRef);
      if (!businessDoc.exists) throw Exception('Business user not found');

      final businessUser = UserModel.fromFirestore(businessDoc);

      final newReviewRef = reviewsRef.doc();
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

  /// Get reviews stream for a business user profile
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

  // ============================================
  // EXISTING: ANNOUNCEMENT REVIEWS
  // ============================================

  Future<void> addReview(ReviewModel review) async {
    if (review.announcementId == null) throw Exception('Announcement ID required');

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

    if (review.targetUserId != null) {
      await _updateUserRatingStats(review.targetUserId!, review.rating);
    }
  }

  Future<void> _updateUserRatingStats(String userId, double newRating) async {
    final userRef = _firestore.collection('users').doc(userId);

    await _firestore.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);
      if (!userDoc.exists) return;

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
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return 0.0;
    final user = UserModel.fromFirestore(doc);
    return user.averageRating;
  }
}

/// Result of a review submission
class ReviewSubmitResult {
  final bool success;
  final String message;
  final String? reviewId;
  final String? existingReviewId;
  final bool moderationFailed;

  ReviewSubmitResult({
    required this.success,
    required this.message,
    this.reviewId,
    this.existingReviewId,
    this.moderationFailed = false,
  });
}

/// Review statistics for a business
class ReviewStats {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> distribution;

  ReviewStats({
    required this.averageRating,
    required this.totalReviews,
    required this.distribution,
  });
}
