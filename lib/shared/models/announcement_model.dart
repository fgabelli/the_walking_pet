import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
  final AnnouncementCategory category; // Added

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
    this.category = AnnouncementCategory.news, // Default
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
      responses: _parseResponses(data['responses']),
      imageUrl: data['imageUrl'],
      authorName: data['authorName'] ?? 'Utente',
      authorPhotoUrl: data['authorPhotoUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      category: AnnouncementCategory.values.firstWhere(
        (e) => e.name == (data['category'] ?? 'news'),
        orElse: () => AnnouncementCategory.news,
      ),
    );
  }

  /// Parse responses array safely — skip individual broken entries
  static List<AnnouncementResponse> _parseResponses(dynamic raw) {
    if (raw == null || raw is! List) return [];
    final List<AnnouncementResponse> results = [];
    for (final entry in raw) {
      try {
        Map<String, dynamic> map;
        if (entry is Map<String, dynamic>) {
          map = entry;
        } else if (entry is Map) {
          map = Map<String, dynamic>.from(entry);
        } else {
          print('[AnnouncementModel] Skipping non-map response entry: ${entry.runtimeType}');
          continue;
        }
        results.add(AnnouncementResponse.fromMap(map));
      } catch (e) {
        // Skip broken response instead of failing entire list
        print('[AnnouncementModel] Skipping malformed response: $e');
      }
    }
    return results;
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
      'category': category.name,
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
    AnnouncementCategory? category,
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
      category: category ?? this.category,
    );
  }
}

enum AnnouncementCategory {
  news,
  lost,
  walk,
  training,
  social,
  litter,
  advice,
  adoption,
  other,
}

extension AnnouncementCategoryExtension on AnnouncementCategory {
  String get displayName {
    switch (this) {
      case AnnouncementCategory.news:
        return 'Novità';
      case AnnouncementCategory.lost:
        return 'Smarrito';
      case AnnouncementCategory.walk:
        return 'Passeggiata';
      case AnnouncementCategory.training:
        return 'Addestramento';
      case AnnouncementCategory.social:
        return 'Raduno / Incontri';
      case AnnouncementCategory.litter:
        return 'Cucciolata 🐾';
      case AnnouncementCategory.advice:
        return 'Consiglio';
      case AnnouncementCategory.adoption:
        return 'Adozione 🏡';
      case AnnouncementCategory.other:
        return 'Altro';
    }
  }

  MaterialColor get color {
    switch (this) {
      case AnnouncementCategory.news:
        return Colors.blue;
      case AnnouncementCategory.lost:
        return Colors.red;
      case AnnouncementCategory.walk:
        return Colors.green;
      case AnnouncementCategory.training:
        return Colors.orange;
      case AnnouncementCategory.social:
        return Colors.purple;
      case AnnouncementCategory.litter:
        return Colors.pink;
      case AnnouncementCategory.advice:
        return Colors.amber;
      case AnnouncementCategory.adoption:
        return Colors.teal;
      case AnnouncementCategory.other:
        return Colors.grey;
    }
  }

  IconData get icon {
    switch (this) {
      case AnnouncementCategory.news:
        return Icons.campaign;
      case AnnouncementCategory.lost:
        return Icons.warning;
      case AnnouncementCategory.walk:
        return Icons.directions_walk;
      case AnnouncementCategory.training:
        return Icons.school;
      case AnnouncementCategory.social:
        return Icons.people;
      case AnnouncementCategory.litter:
        return Icons.pets;
      case AnnouncementCategory.advice:
        return Icons.lightbulb;
      case AnnouncementCategory.adoption:
        return Icons.volunteer_activism;
      case AnnouncementCategory.other:
        return Icons.more_horiz;
    }
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
    DateTime parsedTimestamp;
    try {
      final ts = map['timestamp'];
      if (ts is Timestamp) {
        parsedTimestamp = ts.toDate();
      } else if (ts is DateTime) {
        parsedTimestamp = ts;
      } else {
        parsedTimestamp = DateTime.now();
      }
    } catch (_) {
      parsedTimestamp = DateTime.now();
    }

    return AnnouncementResponse(
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Utente',
      userPhotoUrl: map['userPhotoUrl'],
      type: ResponseType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ResponseType.message,
      ),
      message: map['message'],
      timestamp: parsedTimestamp,
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
