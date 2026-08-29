import 'package:cloud_firestore/cloud_firestore.dart';

enum HealthRecordType {
  vaccine,
  treatment,
  surgery,
  visit,
  other
}

extension HealthRecordTypeExtension on HealthRecordType {
  String get displayName {
    switch (this) {
      case HealthRecordType.vaccine:
        return 'Vaccino';
      case HealthRecordType.treatment:
        return 'Trattamento';
      case HealthRecordType.surgery:
        return 'Chirurgia';
      case HealthRecordType.visit:
        return 'Visita Vet';
      case HealthRecordType.other:
        return 'Altro';
    }
  }
}

class HealthRecordModel {
  final String id;
  final String petId;
  final HealthRecordType type;
  final String title;
  final String? specificName; // e.g. "Antirabbica", "Leptospirosi", "Antipulci"
  final DateTime date;
  final DateTime? nextDueDate;
  final bool reminderEnabled; // Send push notification for nextDueDate
  final bool isCompleted; // Mark if this record is a historical fact or a planned future task
  final String? veterinarianName;
  final String? notes;
  final String? attachmentUrl;

  HealthRecordModel({
    required this.id,
    required this.petId,
    required this.type,
    required this.title,
    this.specificName,
    required this.date,
    this.nextDueDate,
    this.reminderEnabled = true,
    this.isCompleted = true,
    this.veterinarianName,
    this.notes,
    this.attachmentUrl,
  });

  factory HealthRecordModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HealthRecordModel(
      id: doc.id,
      petId: data['petId'] ?? '',
      type: HealthRecordType.values.firstWhere(
        (e) => e.name == data['type'] || e.toString() == data['type'],
        orElse: () => HealthRecordType.other,
      ),
      title: data['title'] ?? '',
      specificName: data['specificName'],
      date: (data['date'] as Timestamp).toDate(),
      nextDueDate: data['nextDueDate'] != null 
          ? (data['nextDueDate'] as Timestamp).toDate() 
          : null,
      reminderEnabled: data['reminderEnabled'] ?? true,
      isCompleted: data['isCompleted'] ?? true,
      veterinarianName: data['veterinarianName'],
      notes: data['notes'],
      attachmentUrl: data['attachmentUrl'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'petId': petId,
      'type': type.name, // Changed to .name for cleaner data
      'title': title,
      'specificName': specificName,
      'date': Timestamp.fromDate(date),
      'nextDueDate': nextDueDate != null ? Timestamp.fromDate(nextDueDate!) : null,
      'reminderEnabled': reminderEnabled,
      'isCompleted': isCompleted,
      'veterinarianName': veterinarianName,
      'notes': notes,
      'attachmentUrl': attachmentUrl,
    };
  }

  HealthRecordModel copyWith({
    String? id,
    String? petId,
    HealthRecordType? type,
    String? title,
    String? specificName,
    DateTime? date,
    DateTime? nextDueDate,
    bool? reminderEnabled,
    bool? isCompleted,
    String? veterinarianName,
    String? notes,
    String? attachmentUrl,
  }) {
    return HealthRecordModel(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      type: type ?? this.type,
      title: title ?? this.title,
      specificName: specificName ?? this.specificName,
      date: date ?? this.date,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      isCompleted: isCompleted ?? this.isCompleted,
      veterinarianName: veterinarianName ?? this.veterinarianName,
      notes: notes ?? this.notes,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
    );
  }
}

