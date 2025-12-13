import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String authorId;
  final String authorName; // De-normalized for display
  final String? authorPhotoUrl; // De-normalized for display
  final String? announcementId; // Optional: for Nextdoor reviews
  final String? targetUserId; // Optional: for Business Profile reviews
  final double rating;
  final String comment;
  final DateTime timestamp;

  ReviewModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    this.announcementId,
    this.targetUserId,
    required this.rating,
    required this.comment,
    required this.timestamp,
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
      rating: (data['rating'] ?? 0.0).toDouble(),
      comment: data['comment'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'announcementId': announcementId,
      'targetUserId': targetUserId,
      'rating': rating,
      'comment': comment,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
