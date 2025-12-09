import 'package:cloud_firestore/cloud_firestore.dart';

/// Dog model
class DogModel {
  final String id;
  final String ownerId;
  final String name;
  final String breed;
  final int age;
  final DogSize size;
  final int energyLevel; // 1-5
  final List<String> character;
  final String? notes;
  final String? photoUrl;
  final DateTime createdAt;
  final DogGender gender;

  DogModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.breed,
    required this.age,
    required this.size,
    required this.energyLevel,
    required this.character,
    this.notes,
    this.photoUrl,
    required this.createdAt,
    this.gender = DogGender.male,
  });

  factory DogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DogModel(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      name: data['name'] ?? '',
      breed: data['breed'] ?? '',
      age: data['age'] ?? 0,
      size: DogSize.values.firstWhere(
        (e) => e.name == data['size'],
        orElse: () => DogSize.medium,
      ),
      energyLevel: data['energyLevel'] ?? 3,
      character: List<String>.from(data['character'] ?? []),
      notes: data['notes'],
      photoUrl: data['photoUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      gender: DogGender.values.firstWhere(
        (e) => e.name == (data['gender'] ?? 'male'),
        orElse: () => DogGender.male,
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'name': name,
      'breed': breed,
      'age': age,
      'size': size.name,
      'energyLevel': energyLevel,
      'character': character,
      'notes': notes,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'gender': gender.name,
    };
  }

  DogModel copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? breed,
    int? age,
    DogSize? size,
    int? energyLevel,
    List<String>? character,
    String? notes,
    String? photoUrl,
    DateTime? createdAt,
    DogGender? gender,
  }) {
    return DogModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      breed: breed ?? this.breed,
      age: age ?? this.age,
      size: size ?? this.size,
      energyLevel: energyLevel ?? this.energyLevel,
      character: character ?? this.character,
      notes: notes ?? this.notes,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      gender: gender ?? this.gender,
    );
  }
}

enum DogSize {
  small,
  medium,
  large,
  giant,
}

extension DogSizeExtension on DogSize {
  String get displayName {
    switch (this) {
      case DogSize.small:
        return 'Piccola';
      case DogSize.medium:
        return 'Media';
      case DogSize.large:
        return 'Grande';
      case DogSize.giant:
        return 'Gigante';
    }
  }
}

enum DogGender {
  male,
  female,
}

extension DogGenderExtension on DogGender {
  String get displayName {
    switch (this) {
      case DogGender.male:
        return 'Maschio';
      case DogGender.female:
        return 'Femmina';
    }
  }
}
