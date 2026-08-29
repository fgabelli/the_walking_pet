import 'package:cloud_firestore/cloud_firestore.dart';

class ReelModel {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String videoUrl;
  final String? thumbnailUrl;
  final String? caption;
  final int durationMs; // duration in milliseconds
  final List<String> likes;
  final int commentCount;
  final int viewCount;
  final DateTime createdAt;
  final ModerationStatus moderationStatus;

  ReelModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.videoUrl,
    this.thumbnailUrl,
    this.caption,
    this.durationMs = 0,
    this.likes = const [],
    this.commentCount = 0,
    this.viewCount = 0,
    required this.createdAt,
    this.moderationStatus = ModerationStatus.approved,
  });

  bool isLikedBy(String userId) => likes.contains(userId);
  int get likeCount => likes.length;

  factory ReelModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReelModel(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      authorPhotoUrl: data['authorPhotoUrl'],
      videoUrl: data['videoUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'],
      caption: data['caption'],
      durationMs: data['durationMs'] ?? 0,
      likes: List<String>.from(data['likes'] ?? []),
      commentCount: data['commentCount'] ?? 0,
      viewCount: data['viewCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      moderationStatus: ModerationStatus.values.firstWhere(
        (e) => e.name == (data['moderationStatus'] ?? 'approved'),
        orElse: () => ModerationStatus.approved,
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'caption': caption,
      'durationMs': durationMs,
      'likes': likes,
      'commentCount': commentCount,
      'viewCount': viewCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'moderationStatus': moderationStatus.name,
    };
  }
}

enum ModerationStatus {
  pending,
  approved,
  rejected,
}
