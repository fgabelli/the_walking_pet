import 'package:cloud_firestore/cloud_firestore.dart';

class LostPetAlertModel {
  final String id;
  final String ownerId;
  final String petId;
  final double latitude;
  final double longitude;
  final String? message;
  final String contactPhone;
  final DateTime createdAt;
  final bool isActive;

  LostPetAlertModel({
    required this.id,
    required this.ownerId,
    required this.petId,
    required this.latitude,
    required this.longitude,
    this.message,
    required this.contactPhone,
    required this.createdAt,
    required this.isActive,
  });

  factory LostPetAlertModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LostPetAlertModel(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      petId: data['petId'] ?? '',
      latitude: data['latitude'] ?? 0.0,
      longitude: data['longitude'] ?? 0.0,
      message: data['message'],
      contactPhone: data['contactPhone'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'petId': petId,
      'latitude': latitude,
      'longitude': longitude,
      'message': message,
      'contactPhone': contactPhone,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }

  LostPetAlertModel copyWith({
    String? id,
    String? ownerId,
    String? petId,
    double? latitude,
    double? longitude,
    String? message,
    String? contactPhone,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return LostPetAlertModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      petId: petId ?? this.petId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      message: message ?? this.message,
      contactPhone: contactPhone ?? this.contactPhone,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
