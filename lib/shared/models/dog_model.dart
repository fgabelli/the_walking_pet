import 'package:cloud_firestore/cloud_firestore.dart';

enum PetSpecies {
  dog,
  cat,
}

extension PetSpeciesExtension on PetSpecies {
  String get displayName {
    switch (this) {
      case PetSpecies.dog:
        return 'Cane';
      case PetSpecies.cat:
        return 'Gatto';
    }
  }
}

/// Dog model (Renaming to PetModel conceptually, but keeping class name for now to avoid massive refactor)
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
  final List<String> mediaUrls;

  /// Backward compat: ritorna la prima media URL come foto profilo
  String? get photoUrl => mediaUrls.isNotEmpty ? mediaUrls.first : null;
  final DateTime createdAt;
  final DogGender gender;
  final PetSpecies species; // Added
  
  // Medical & Health Fields (Babalù style)
  final String? microchipNumber;
  final double? weight;
  final String? bloodType;
  final List<String> allergies;
  final List<String> intolerances;
  final List<String> pathologies;
  final bool isSterilized;

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
    this.mediaUrls = const [],
    required this.createdAt,
    this.gender = DogGender.male,
    this.species = PetSpecies.dog, // Default for existing records
    this.microchipNumber,
    this.weight,
    this.bloodType,
    this.allergies = const [],
    this.intolerances = const [],
    this.pathologies = const [],
    this.isSterilized = false,
  });

  factory DogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Backward compat: migra il vecchio photoUrl in mediaUrls
    final mediaUrls = List<String>.from(data['mediaUrls'] ?? []);
    if (mediaUrls.isEmpty && data['photoUrl'] != null) {
      mediaUrls.add(data['photoUrl']);
    }

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
      mediaUrls: mediaUrls,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      gender: DogGender.values.firstWhere(
        (e) => e.name == (data['gender'] ?? 'male'),
        orElse: () => DogGender.male,
      ),
      species: PetSpecies.values.firstWhere(
        (e) => e.name == (data['species'] ?? 'dog'),
        orElse: () => PetSpecies.dog,
      ),
      microchipNumber: data['microchipNumber'],
      weight: (data['weight'] as num?)?.toDouble(),
      bloodType: data['bloodType'],
      allergies: List<String>.from(data['allergies'] ?? []),
      intolerances: List<String>.from(data['intolerances'] ?? []),
      pathologies: List<String>.from(data['pathologies'] ?? []),
      isSterilized: data['isSterilized'] ?? false,
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
      'mediaUrls': mediaUrls,
      'photoUrl': photoUrl, // backward compat
      'createdAt': Timestamp.fromDate(createdAt),
      'gender': gender.name,
      'species': species.name,
      'microchipNumber': microchipNumber,
      'weight': weight,
      'bloodType': bloodType,
      'allergies': allergies,
      'intolerances': intolerances,
      'pathologies': pathologies,
      'isSterilized': isSterilized,
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
    List<String>? mediaUrls,
    DateTime? createdAt,
    DogGender? gender,
    PetSpecies? species,
    String? microchipNumber,
    double? weight,
    String? bloodType,
    List<String>? allergies,
    List<String>? intolerances,
    List<String>? pathologies,
    bool? isSterilized,
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
      mediaUrls: mediaUrls ?? this.mediaUrls,
      createdAt: createdAt ?? this.createdAt,
      gender: gender ?? this.gender,
      species: species ?? this.species,
      microchipNumber: microchipNumber ?? this.microchipNumber,
      weight: weight ?? this.weight,
      bloodType: bloodType ?? this.bloodType,
      allergies: allergies ?? this.allergies,
      intolerances: intolerances ?? this.intolerances,
      pathologies: pathologies ?? this.pathologies,
      isSterilized: isSterilized ?? this.isSterilized,
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
