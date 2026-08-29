import 'package:cloud_firestore/cloud_firestore.dart';

class LostPetSightingModel {
  final String id;
  final String alertId;
  final String petId;
  final String ownerId;
  final String finderId;
  final double latitude;
  final double longitude;
  final String photoUrl;
  final String description;
  final DateTime createdAt;

  LostPetSightingModel({
    required this.id,
    required this.alertId,
    required this.petId,
    required this.ownerId,
    required this.finderId,
    required this.latitude,
    required this.longitude,
    required this.photoUrl,
    required this.description,
    required this.createdAt,
  });

  factory LostPetSightingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LostPetSightingModel(
      id: doc.id,
      alertId: data['alertId'] ?? '',
      petId: data['petId'] ?? '',
      ownerId: data['ownerId'] ?? '',
      finderId: data['finderId'] ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      photoUrl: data['photoUrl'] ?? '',
      description: data['description'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'alertId': alertId,
      'petId': petId,
      'ownerId': ownerId,
      'finderId': finderId,
      'latitude': latitude,
      'longitude': longitude,
      'photoUrl': photoUrl,
      'description': description,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
