import 'package:cloud_firestore/cloud_firestore.dart';

enum EventType {
  walk,
  training,
  social,
  other
}

extension EventTypeExtension on EventType {
  String get displayName {
    switch (this) {
      case EventType.walk:
        return 'Passeggiata';
      case EventType.training:
        return 'Addestramento';
      case EventType.social:
        return 'Raduno Social';
      case EventType.other:
        return 'Altro';
    }
  }
}

class EventModel {
  final String id;
  final String title;
  final String description;
  final String creatorId; // User ID of organizer
  final DateTime date;
  final double latitude;
  final double longitude;
  final String locationName; // Human readable address or park name
  final List<String> attendees; // List of User IDs
  final EventType type;
  final String? imageUrl;
  final DateTime createdAt;

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.creatorId,
    required this.date,
    required this.latitude,
    required this.longitude,
    required this.locationName,
    required this.attendees,
    required this.type,
    this.imageUrl,
    required this.createdAt,
  });

  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EventModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      creatorId: data['creatorId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      latitude: (data['location'] as GeoPoint).latitude,
      longitude: (data['location'] as GeoPoint).longitude,
      locationName: data['locationName'] ?? '',
      attendees: List<String>.from(data['attendees'] ?? []),
      type: EventType.values.firstWhere(
        (e) => e.toString() == data['type'],
        orElse: () => EventType.other,
      ),
      imageUrl: data['imageUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'creatorId': creatorId,
      'date': Timestamp.fromDate(date),
      'location': GeoPoint(latitude, longitude),
      'locationName': locationName,
      'attendees': attendees,
      'type': type.toString(),
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
