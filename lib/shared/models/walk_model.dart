import 'package:cloud_firestore/cloud_firestore.dart';

/// Walk/Event model
class WalkModel {
  final String id;
  final String creatorId;
  final String title;
  final String description;
  final DateTime date;
  final int duration; // in minutes
  final MeetingPoint meetingPoint;
  final List<String> participants;
  final int? maxParticipants;
  final String chatId;
  final WalkStatus status;
  final DateTime createdAt;

  WalkModel({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.description,
    required this.date,
    required this.duration,
    required this.meetingPoint,
    required this.participants,
    this.maxParticipants,
    required this.chatId,
    required this.status,
    required this.createdAt,
  });

  factory WalkModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalkModel(
      id: doc.id,
      creatorId: data['creatorId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      duration: data['duration'] ?? 30,
      meetingPoint: MeetingPoint.fromMap(data['meetingPoint'] ?? {}),
      participants: List<String>.from(data['participants'] ?? []),
      maxParticipants: data['maxParticipants'],
      chatId: data['chatId'] ?? '',
      status: WalkStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => WalkStatus.upcoming,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'creatorId': creatorId,
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date),
      'duration': duration,
      'meetingPoint': meetingPoint.toMap(),
      'participants': participants,
      'maxParticipants': maxParticipants,
      'chatId': chatId,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  bool get isFull => maxParticipants != null && participants.length >= maxParticipants!;
  bool get isUpcoming => status == WalkStatus.upcoming && date.isAfter(DateTime.now());
  bool get isOngoing => status == WalkStatus.ongoing;
  bool get isCompleted => status == WalkStatus.completed;

  WalkModel copyWith({
    String? id,
    String? creatorId,
    String? title,
    String? description,
    DateTime? date,
    int? duration,
    MeetingPoint? meetingPoint,
    List<String>? participants,
    int? maxParticipants,
    String? chatId,
    WalkStatus? status,
    DateTime? createdAt,
  }) {
    return WalkModel(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      duration: duration ?? this.duration,
      meetingPoint: meetingPoint ?? this.meetingPoint,
      participants: participants ?? this.participants,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      chatId: chatId ?? this.chatId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class MeetingPoint {
  final double latitude;
  final double longitude;
  final String address;

  MeetingPoint({
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  factory MeetingPoint.fromMap(Map<String, dynamic> map) {
    return MeetingPoint(
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      address: map['address'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
    };
  }
}

enum WalkStatus {
  upcoming,
  ongoing,
  completed,
  cancelled,
}

extension WalkStatusExtension on WalkStatus {
  String get displayName {
    switch (this) {
      case WalkStatus.upcoming:
        return 'In programma';
      case WalkStatus.ongoing:
        return 'In corso';
      case WalkStatus.completed:
        return 'Completata';
      case WalkStatus.cancelled:
        return 'Annullata';
    }
  }
}
