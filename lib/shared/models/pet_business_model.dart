import 'package:cloud_firestore/cloud_firestore.dart';

/// Category of pet-related business
enum PetBusinessCategory {
  vetClinic,
  petShop,
  groomer,
  petSitter,
  dogTrainer,
  petHotel,
  petFriendlyCafe,
  petPharmacy,
  dogPark,
  petFriendlyBeach,
  petFriendlyBathhouse,
  other;

  String get displayName {
    switch (this) {
      case PetBusinessCategory.vetClinic:
        return 'Veterinario';
      case PetBusinessCategory.petShop:
        return 'Pet Shop';
      case PetBusinessCategory.groomer:
        return 'Toelettatura';
      case PetBusinessCategory.petSitter:
        return 'Pet Sitter';
      case PetBusinessCategory.dogTrainer:
        return 'Educatore Cinofilo';
      case PetBusinessCategory.petHotel:
        return 'Pensione Animali';
      case PetBusinessCategory.petFriendlyCafe:
        return 'Locale Pet Friendly';
      case PetBusinessCategory.petPharmacy:
        return 'Farmacia Veterinaria';
      case PetBusinessCategory.dogPark:
        return 'Area Cani';
      case PetBusinessCategory.petFriendlyBeach:
        return 'Spiaggia Libera Pet Friendly';
      case PetBusinessCategory.petFriendlyBathhouse:
        return 'Stabilimento Pet Friendly';
      case PetBusinessCategory.other:
        return 'Altro';
    }
  }

  String get icon {
    switch (this) {
      case PetBusinessCategory.vetClinic:
        return '🏥';
      case PetBusinessCategory.petShop:
        return '🛍️';
      case PetBusinessCategory.groomer:
        return '✂️';
      case PetBusinessCategory.petSitter:
        return '🏠';
      case PetBusinessCategory.dogTrainer:
        return '🎓';
      case PetBusinessCategory.petHotel:
        return '🏨';
      case PetBusinessCategory.petFriendlyCafe:
        return '☕';
      case PetBusinessCategory.petPharmacy:
        return '💊';
      case PetBusinessCategory.dogPark:
        return '🐕';
      case PetBusinessCategory.petFriendlyBeach:
        return '🏖️';
      case PetBusinessCategory.petFriendlyBathhouse:
        return '🏝️';
      case PetBusinessCategory.other:
        return '📍';
    }
  }

  /// Map Google Places types to our categories
  static PetBusinessCategory fromGoogleType(List<String> types) {
    if (types.contains('veterinary_care')) return PetBusinessCategory.vetClinic;
    if (types.contains('pet_store')) return PetBusinessCategory.petShop;
    if (types.contains('park')) return PetBusinessCategory.dogPark;
    return PetBusinessCategory.other;
  }

  /// Whether this category can be claimed by a business owner
  bool get canBeClaimed {
    switch (this) {
      case PetBusinessCategory.dogPark:
      case PetBusinessCategory.petFriendlyBeach:
        return false; // Public spaces, no owner
      default:
        return true;
    }
  }
}

/// Model for a pet-related business
class PetBusinessModel {
  final String id; // Firestore doc ID or Google Places placeId
  final String? googlePlaceId; // For linking to Google data
  final String name;
  final String? description;
  final String address;
  final double latitude;
  final double longitude;
  final PetBusinessCategory category;
  final String? phone;
  final String? website;
  final double? rating; // Google rating
  final int? userRatingsTotal;
  final List<String> photos; // URLs
  final String? openNow; // "Aperto" / "Chiuso"
  final bool isClaimed; // Whether a business owner has claimed it
  final String? claimedByUserId; // UID of the owner who claimed it
  final DateTime? claimedAt;
  final Map<String, String>? openingHours; // Day -> Hours
  final List<String> services; // e.g. "Visite a domicilio", "Emergenze H24"
  final DateTime createdAt;
  final DateTime? updatedAt;

  PetBusinessModel({
    required this.id,
    this.googlePlaceId,
    required this.name,
    this.description,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.category = PetBusinessCategory.other,
    this.phone,
    this.website,
    this.rating,
    this.userRatingsTotal,
    this.photos = const [],
    this.openNow,
    this.isClaimed = false,
    this.claimedByUserId,
    this.claimedAt,
    this.openingHours,
    this.services = const [],
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create from Google Places Nearby Search result
  factory PetBusinessModel.fromGooglePlace(Map<String, dynamic> place) {
    final location = place['geometry']?['location'] ?? {};
    final types = List<String>.from(place['types'] ?? []);

    return PetBusinessModel(
      id: place['place_id'] ?? '',
      googlePlaceId: place['place_id'],
      name: place['name'] ?? 'Sconosciuto',
      address: place['vicinity'] ?? '',
      latitude: (location['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (location['lng'] as num?)?.toDouble() ?? 0.0,
      category: PetBusinessCategory.fromGoogleType(types),
      rating: (place['rating'] as num?)?.toDouble(),
      userRatingsTotal: place['user_ratings_total'] as int?,
      openNow: place['opening_hours']?['open_now'] == true
          ? 'Aperto'
          : (place['opening_hours'] != null ? 'Chiuso' : null),
      photos: [], // Photo references need additional API call
    );
  }

  /// Create from Firestore document
  factory PetBusinessModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PetBusinessModel(
      id: doc.id,
      googlePlaceId: data['googlePlaceId'],
      name: data['name'] ?? '',
      description: data['description'],
      address: data['address'] ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      category: PetBusinessCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => PetBusinessCategory.other,
      ),
      phone: data['phone'],
      website: data['website'],
      rating: (data['rating'] as num?)?.toDouble(),
      userRatingsTotal: data['userRatingsTotal'] as int?,
      photos: List<String>.from(data['photos'] ?? []),
      openNow: data['openNow'],
      isClaimed: data['isClaimed'] ?? false,
      claimedByUserId: data['claimedByUserId'],
      claimedAt: (data['claimedAt'] as Timestamp?)?.toDate(),
      openingHours: data['openingHours'] != null
          ? Map<String, String>.from(data['openingHours'])
          : null,
      services: List<String>.from(data['services'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'googlePlaceId': googlePlaceId,
      'name': name,
      'description': description,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'category': category.name,
      'phone': phone,
      'website': website,
      'rating': rating,
      'userRatingsTotal': userRatingsTotal,
      'photos': photos,
      'openNow': openNow,
      'isClaimed': isClaimed,
      'claimedByUserId': claimedByUserId,
      'claimedAt': claimedAt != null ? Timestamp.fromDate(claimedAt!) : null,
      'openingHours': openingHours,
      'services': services,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  PetBusinessModel copyWith({
    String? id,
    String? googlePlaceId,
    String? name,
    String? description,
    String? address,
    double? latitude,
    double? longitude,
    PetBusinessCategory? category,
    String? phone,
    String? website,
    double? rating,
    int? userRatingsTotal,
    List<String>? photos,
    String? openNow,
    bool? isClaimed,
    String? claimedByUserId,
    DateTime? claimedAt,
    Map<String, String>? openingHours,
    List<String>? services,
  }) {
    return PetBusinessModel(
      id: id ?? this.id,
      googlePlaceId: googlePlaceId ?? this.googlePlaceId,
      name: name ?? this.name,
      description: description ?? this.description,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      rating: rating ?? this.rating,
      userRatingsTotal: userRatingsTotal ?? this.userRatingsTotal,
      photos: photos ?? this.photos,
      openNow: openNow ?? this.openNow,
      isClaimed: isClaimed ?? this.isClaimed,
      claimedByUserId: claimedByUserId ?? this.claimedByUserId,
      claimedAt: claimedAt ?? this.claimedAt,
      openingHours: openingHours ?? this.openingHours,
      services: services ?? this.services,
      createdAt: createdAt,
    );
  }
}
