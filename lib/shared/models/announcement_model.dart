import 'package:cloud_firestore/cloud_firestore.dart';

/// Announcement model for NextDoor feature
/// Updated with images and responses
class AnnouncementModel {
  final String id;
  final String userId;
  final String message;
  final String zone;
  final AnnouncementLocation location;
  final DateTime? scheduledTime;
  final List<AnnouncementResponse> responses;
  final String? imageUrl;
  final String authorName;
  final String? authorPhotoUrl;
  final DateTime createdAt;
  final DateTime expiresAt;

  AnnouncementModel({
    required this.id,
    required this.userId,
    required this.message,
    required this.zone,
    required this.location,
    this.scheduledTime,
    required this.responses,
    this.imageUrl,
    required this.authorName,
    this.authorPhotoUrl,
    required this.createdAt,
    required this.expiresAt,
  });

  factory AnnouncementModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AnnouncementModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      message: data['message'] ?? '',
      zone: data['zone'] ?? '',
      location: AnnouncementLocation.fromMap(data['location'] ?? {}),
      scheduledTime: data['scheduledTime'] != null
          ? (data['scheduledTime'] as Timestamp).toDate()
          : null,
      responses: (data['responses'] as List<dynamic>?)
              ?.map((e) => AnnouncementResponse.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      imageUrl: data['imageUrl'],
      authorName: data['authorName'] ?? 'Utente',
      authorPhotoUrl: data['authorPhotoUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'message': message,
      'zone': zone,
      'location': location.toMap(),
      'scheduledTime': scheduledTime != null ? Timestamp.fromDate(scheduledTime!) : null,
      'responses': responses.map((e) => e.toMap()).toList(),
      'imageUrl': imageUrl,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isActive => !isExpired;

  AnnouncementModel copyWith({
    String? id,
    String? userId,
    String? message,
    String? zone,
    AnnouncementLocation? location,
    DateTime? scheduledTime,
    List<AnnouncementResponse>? responses,
    String? imageUrl,
    String? authorName,
    String? authorPhotoUrl,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return AnnouncementModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      message: message ?? this.message,
      zone: zone ?? this.zone,
      location: location ?? this.location,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      responses: responses ?? this.responses,
      imageUrl: imageUrl ?? this.imageUrl,
      authorName: authorName ?? this.authorName,
      authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}

class AnnouncementLocation {
  final double latitude;
  final double longitude;
  final String geohash;

  AnnouncementLocation({
    required this.latitude,
    required this.longitude,
    required this.geohash,
  });

  factory AnnouncementLocation.fromMap(Map<String, dynamic> map) {
    if (map['geopoint'] != null) {
      final geoPoint = map['geopoint'] as GeoPoint;
      return AnnouncementLocation(
        latitude: geoPoint.latitude,
        longitude: geoPoint.longitude,
        geohash: map['geohash'] ?? '',
      );
    }
    // Fallback for legacy data or missing geopoint
    return AnnouncementLocation(
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      geohash: map['geohash'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'geohash': geohash,
      'geopoint': GeoPoint(latitude, longitude),
    };
  }
}

class AnnouncementResponse {
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final ResponseType type;
  final String? message;
  final DateTime timestamp;

  AnnouncementResponse({
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.type,
    this.message,
    required this.timestamp,
  });

  factory AnnouncementResponse.fromMap(Map<String, dynamic> map) {
    return AnnouncementResponse(
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Utente',
      userPhotoUrl: map['userPhotoUrl'],
      type: ResponseType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ResponseType.message,
      ),
      message: map['message'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'type': type.name,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

enum ResponseType {
  join,
  watching,
  message,
}

extension ResponseTypeExtension on ResponseType {
  String get displayName {
    switch (this) {
      case ResponseType.join:
        return 'Mi unisco';
      case ResponseType.watching:
        return 'Tengo d\'occhio';
      case ResponseType.message:
        return 'Messaggio';
    }
  }
}
