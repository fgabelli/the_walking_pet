import 'package:cloud_firestore/cloud_firestore.dart';

/// Moderation status for user-generated content
enum ModerationStatus {
  pending,   // Awaiting moderation
  approved,  // Content approved
  rejected,  // Content rejected (hidden)
  flagged;   // Flagged by users for manual review

  String get displayName {
    switch (this) {
      case ModerationStatus.pending:
        return 'In attesa';
      case ModerationStatus.approved:
        return 'Approvato';
      case ModerationStatus.rejected:
        return 'Rimosso';
      case ModerationStatus.flagged:
        return 'Segnalato';
    }
  }
}

class ReviewModel {
  final String id;
  final String authorId;
  final String authorName; // De-normalized for display
  final String? authorPhotoUrl; // De-normalized for display
  final String? announcementId; // Optional: for Bacheca reviews
  final String? targetUserId; // Optional: for Business Profile reviews
  final String? businessId; // For Pet Business / Dog Park reviews
  final double rating;
  final String comment;
  final DateTime timestamp;
  final ModerationStatus moderationStatus;
  final String? moderationNote; // Reason for rejection
  final int reportCount; // Number of user reports/flags
  final List<String> reportedByUserIds; // Who reported it

  ReviewModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    this.announcementId,
    this.targetUserId,
    this.businessId,
    required this.rating,
    required this.comment,
    required this.timestamp,
    this.moderationStatus = ModerationStatus.approved, // Auto-approve if passes filter
    this.moderationNote,
    this.reportCount = 0,
    this.reportedByUserIds = const [],
  });

  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReviewModel(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Utente',
      authorPhotoUrl: data['authorPhotoUrl'],
      announcementId: data['announcementId'],
      targetUserId: data['targetUserId'],
      businessId: data['businessId'],
      rating: (data['rating'] ?? 0.0).toDouble(),
      comment: data['comment'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      moderationStatus: ModerationStatus.values.firstWhere(
        (e) => e.name == data['moderationStatus'],
        orElse: () => ModerationStatus.approved,
      ),
      moderationNote: data['moderationNote'],
      reportCount: data['reportCount'] ?? 0,
      reportedByUserIds: List<String>.from(data['reportedByUserIds'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'announcementId': announcementId,
      'targetUserId': targetUserId,
      'businessId': businessId,
      'rating': rating,
      'comment': comment,
      'timestamp': Timestamp.fromDate(timestamp),
      'moderationStatus': moderationStatus.name,
      'moderationNote': moderationNote,
      'reportCount': reportCount,
      'reportedByUserIds': reportedByUserIds,
    };
  }

  /// Whether this review should be visible to users
  bool get isVisible =>
      moderationStatus == ModerationStatus.approved ||
      moderationStatus == ModerationStatus.pending;
}
