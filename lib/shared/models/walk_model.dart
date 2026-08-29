import 'package:cloud_firestore/cloud_firestore.dart';

/// Walk/Event model
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
  final Recurrence recurrence; // Added
  final List<int> recurrenceDays; // Added: 1 = Mon, 7 = Sun

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
    this.recurrence = Recurrence.none, // Default
    this.recurrenceDays = const [], // Default empty
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
      recurrence: Recurrence.values.firstWhere(
        (e) => e.name == (data['recurrence'] ?? 'none'),
        orElse: () => Recurrence.none,
      ),
      recurrenceDays: List<int>.from(data['recurrenceDays'] ?? []), // Added
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'creatorId': creatorId,
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date),
      'duration': duration, // This was missing in previous view but logic implies it should be kept
      'meetingPoint': meetingPoint.toMap(),
      'participants': participants,
      'maxParticipants': maxParticipants,
      'chatId': chatId,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'recurrence': recurrence.name,
      'recurrenceDays': recurrenceDays, // Added
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
    Recurrence? recurrence,
    List<int>? recurrenceDays, // Added
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
      recurrence: recurrence ?? this.recurrence,
      recurrenceDays: recurrenceDays ?? this.recurrenceDays, // Added
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

enum Recurrence {
  none,
  daily,
  weekly,
  custom, // Added
}

extension RecurrenceExtension on Recurrence {
  String get displayName {
    switch (this) {
      case Recurrence.none:
        return 'Nessuna';
      case Recurrence.daily:
        return 'Ogni Giorno';
      case Recurrence.weekly:
        return 'Ogni Settimana';
      case Recurrence.custom:
        return 'Giorni Personalizzati'; // Added
    }
  }
}
