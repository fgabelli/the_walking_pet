import 'package:cloud_firestore/cloud_firestore.dart';

/// User model
class UserModel {
  final String uid;
  final String firstName;
  final String lastName;
  final String email;
  final String? photoUrl;
  final String? bio;
  final String zone;
  final SocialPreferences socialPreferences;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> fcmTokens;
  
  // New Privacy & Friendship Fields
  final LocationPrivacy locationPrivacy;
  final List<String> friends;
  final List<String> friendRequests; // Incoming requests
  final List<String> locationWhitelist; // For 'custom' privacy
  
  // Personal Info
  final Gender? gender;
  final DateTime? birthDate;
  final String? address;

  UserModel({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.photoUrl,
    this.bio,
    required this.zone,
    required this.socialPreferences,
    required this.createdAt,
    required this.updatedAt,
    this.fcmTokens = const [],
    this.locationPrivacy = LocationPrivacy.friends,
    this.friends = const [],
    this.friendRequests = const [],
    this.locationWhitelist = const [],
    this.gender,
    this.birthDate,
    this.address,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'],
      bio: data['bio'],
      zone: data['zone'] ?? '',
      socialPreferences: SocialPreferences.fromMap(data['socialPreferences'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      fcmTokens: List<String>.from(data['fcmTokens'] ?? []),
      locationPrivacy: LocationPrivacy.values.firstWhere(
        (e) => e.name == (data['locationPrivacy'] ?? 'friends'),
        orElse: () => LocationPrivacy.friends,
      ),
      friends: List<String>.from(data['friends'] ?? []),
      friendRequests: List<String>.from(data['friendRequests'] ?? []),
      locationWhitelist: List<String>.from(data['locationWhitelist'] ?? []),
      gender: data['gender'] != null 
          ? Gender.values.firstWhere((e) => e.name == data['gender'], orElse: () => Gender.other)
          : null,
      birthDate: data['birthDate'] != null ? (data['birthDate'] as Timestamp).toDate() : null,
      address: data['address'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'photoUrl': photoUrl,
      'bio': bio,
      'zone': zone,
      'socialPreferences': socialPreferences.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'fcmTokens': fcmTokens,
      'locationPrivacy': locationPrivacy.name,
      'friends': friends,
      'friendRequests': friendRequests,
      'locationWhitelist': locationWhitelist,
      'gender': gender?.name,
      'birthDate': birthDate != null ? Timestamp.fromDate(birthDate!) : null,
      'address': address,
    };
  }

  String get fullName => '$firstName $lastName';

  UserModel copyWith({
    String? uid,
    String? firstName,
    String? lastName,
    String? email,
    String? photoUrl,
    String? bio,
    String? zone,
    SocialPreferences? socialPreferences,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? fcmTokens,
    LocationPrivacy? locationPrivacy,
    List<String>? friends,
    List<String>? friendRequests,
    List<String>? locationWhitelist,
    Gender? gender,
    DateTime? birthDate,
    String? address,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      zone: zone ?? this.zone,
      socialPreferences: socialPreferences ?? this.socialPreferences,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      locationPrivacy: locationPrivacy ?? this.locationPrivacy,
      friends: friends ?? this.friends,
      friendRequests: friendRequests ?? this.friendRequests,
      locationWhitelist: locationWhitelist ?? this.locationWhitelist,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      address: address ?? this.address,
    );
  }
}

/// Social preferences for user privacy
class SocialPreferences {
  final Visibility visibility;
  final bool shareLocation;
  final int locationRadius; // in meters

  SocialPreferences({
    this.visibility = Visibility.public,
    this.shareLocation = true,
    this.locationRadius = 5000,
  });

  factory SocialPreferences.fromMap(Map<String, dynamic> map) {
    return SocialPreferences(
      visibility: Visibility.values.firstWhere(
        (e) => e.name == map['visibility'],
        orElse: () => Visibility.public,
      ),
      shareLocation: map['shareLocation'] ?? true,
      locationRadius: map['locationRadius'] ?? 5000,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'visibility': visibility.name,
      'shareLocation': shareLocation,
      'locationRadius': locationRadius,
    };
  }

  SocialPreferences copyWith({
    Visibility? visibility,
    bool? shareLocation,
    int? locationRadius,
  }) {
    return SocialPreferences(
      visibility: visibility ?? this.visibility,
      shareLocation: shareLocation ?? this.shareLocation,
      locationRadius: locationRadius ?? this.locationRadius,
    );
  }
}

enum Visibility {
  public,
  friends,
  invisible,
}

enum LocationPrivacy {
  everyone,
  friends,
  custom,
}

enum Gender {
  male,
  female,
  other,
}

extension GenderExtension on Gender {
  String get displayName {
    switch (this) {
      case Gender.male:
        return 'Uomo';
      case Gender.female:
        return 'Donna';
      case Gender.other:
        return 'Altro';
    }
  }
}
