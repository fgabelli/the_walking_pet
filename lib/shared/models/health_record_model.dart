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
  final DateTime date;
  final DateTime? nextDueDate;
  final String? veterinarianName;
  final String? notes;
  final String? attachmentUrl;

  HealthRecordModel({
    required this.id,
    required this.petId,
    required this.type,
    required this.title,
    required this.date,
    this.nextDueDate,
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
        (e) => e.toString() == data['type'],
        orElse: () => HealthRecordType.other,
      ),
      title: data['title'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      nextDueDate: data['nextDueDate'] != null 
          ? (data['nextDueDate'] as Timestamp).toDate() 
          : null,
      veterinarianName: data['veterinarianName'],
      notes: data['notes'],
      attachmentUrl: data['attachmentUrl'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'petId': petId,
      'type': type.toString(),
      'title': title,
      'date': Timestamp.fromDate(date),
      'nextDueDate': nextDueDate != null ? Timestamp.fromDate(nextDueDate!) : null,
      'veterinarianName': veterinarianName,
      'notes': notes,
      'attachmentUrl': attachmentUrl,
    };
  }
}
