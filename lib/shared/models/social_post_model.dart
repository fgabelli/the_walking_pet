import 'package:cloud_firestore/cloud_firestore.dart';

class SocialPostModel {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String? petName;
  final String? petPhotoUrl;
  final String? text;
  final String? imageUrl;
  final PostType type;
  final List<String> likes;
  final int commentCount;
  final DateTime createdAt;

  SocialPostModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    this.petName,
    this.petPhotoUrl,
    this.text,
    this.imageUrl,
    this.type = PostType.photo,
    this.likes = const [],
    this.commentCount = 0,
    required this.createdAt,
  });

  bool isLikedBy(String userId) => likes.contains(userId);
  int get likeCount => likes.length;

  factory SocialPostModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SocialPostModel(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      authorPhotoUrl: data['authorPhotoUrl'],
      petName: data['petName'],
      petPhotoUrl: data['petPhotoUrl'],
      text: data['text'],
      imageUrl: data['imageUrl'],
      type: PostType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'photo'),
        orElse: () => PostType.photo,
      ),
      likes: List<String>.from(data['likes'] ?? []),
      commentCount: data['commentCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'petName': petName,
      'petPhotoUrl': petPhotoUrl,
      'text': text,
      'imageUrl': imageUrl,
      'type': type.name,
      'likes': likes,
      'commentCount': commentCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class PostCommentModel {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String text;
  final DateTime createdAt;

  PostCommentModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.text,
    required this.createdAt,
  });

  factory PostCommentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PostCommentModel(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? '',
      authorPhotoUrl: data['authorPhotoUrl'],
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

enum PostType {
  photo,
  story,
  walkCard,
  video,
}

extension PostTypeExtension on PostType {
  String get displayName {
    switch (this) {
      case PostType.photo:
        return 'Foto';
      case PostType.story:
        return 'Storia';
      case PostType.walkCard:
        return 'Walk Card';
      case PostType.video:
        return 'Video';
    }
  }
}
