import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum EventType {
  news,
  lost,
  walk,
  training,
  social,
  litter,
  advice,
  other,
}

extension EventTypeExtension on EventType {
  String get displayName {
    switch (this) {
      case EventType.news:
        return 'Novità';
      case EventType.lost:
        return 'Smarrito';
      case EventType.walk:
        return 'Passeggiata';
      case EventType.training:
        return 'Addestramento';
      case EventType.social:
        return 'Raduno / Incontri';
      case EventType.litter:
        return 'Cucciolata 🐾';
      case EventType.advice:
        return 'Consiglio';
      case EventType.other:
        return 'Altro';
    }
  }

  IconData get icon {
    switch (this) {
      case EventType.news:
        return Icons.campaign;
      case EventType.lost:
        return Icons.warning;
      case EventType.walk:
        return Icons.directions_walk;
      case EventType.training:
        return Icons.school;
      case EventType.social:
        return Icons.people;
      case EventType.litter:
        return Icons.pets;
      case EventType.advice:
        return Icons.lightbulb;
      case EventType.other:
        return Icons.more_horiz;
    }
  }

  Color get color {
    switch (this) {
      case EventType.news:
        return Colors.blue;
      case EventType.lost:
        return Colors.red;
      case EventType.walk:
        return Colors.green;
      case EventType.training:
        return Colors.orange;
      case EventType.social:
        return Colors.purple;
      case EventType.litter:
        return Colors.pink;
      case EventType.advice:
        return Colors.amber;
      case EventType.other:
        return Colors.grey;
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
