import 'package:cloud_firestore/cloud_firestore.dart';

enum SafetyAlertType {
  poison, // Bocconi avvelenati
  glass, // Vetri rotti
  aggression, // Cane aggressivo
  police, // Controlli
  other // Altro
}

extension SafetyAlertTypeExtension on SafetyAlertType {
  String get displayName {
    switch (this) {
      case SafetyAlertType.poison:
        return 'Bocconi Avvelenati';
      case SafetyAlertType.glass:
        return 'Vetri/Pericoli';
      case SafetyAlertType.aggression:
        return 'Animale Aggressivo';
      case SafetyAlertType.police:
        return 'Controlli';
      case SafetyAlertType.other:
        return 'Altro';
    }
  }
}

class SafetyAlertModel {
  final String id;
  final String authorId;
  final SafetyAlertType type;
  final double latitude;
  final double longitude;
  final String? description;
  final DateTime createdAt;
  final DateTime expiresAt;

  SafetyAlertModel({
    required this.id,
    required this.authorId,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.description,
    required this.createdAt,
    required this.expiresAt,
  });

  factory SafetyAlertModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SafetyAlertModel(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      type: SafetyAlertType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'other'),
        orElse: () => SafetyAlertType.other,
      ),
      latitude: data['latitude'] ?? 0.0,
      longitude: data['longitude'] ?? 0.0,
      description: data['description'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'authorId': authorId,
      'type': type.name,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }
}
