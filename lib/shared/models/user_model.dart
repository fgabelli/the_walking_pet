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
  final List<String> blockedUsers; // New field for blocked users
  final List<String> followers; // Users following this profile (Business)
  final List<String> following; // Profiles this user is following
  final bool isGhost; // New field for Ghost Mode (Premium)

  // Monetization Fields
  final bool isPremium;
  final AccountType accountType;
  final String? businessCategory; // Only for business accounts
  final String? website;
  final String? phoneNumber;
  
  // Rich Business Profile Fields
  final String? coverImageUrl;
  final List<String> galleryImages;
  final String? openingHours; // Simplified text for now (e.g. "Lun-Ven: 9-18")
  final String? instagramHandle;
  final String? tiktokHandle;
  
  // Personal Info
  final Gender? gender;
  final DateTime? birthDate;
  final String? address;
  
  // Reviews
  final double averageRating;
  final int reviewCount;

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
    this.blockedUsers = const [],
    this.followers = const [],
    this.following = const [],
    this.isGhost = false,
    this.isPremium = false,
    this.accountType = AccountType.personal,
    this.businessCategory,
    this.website,
    this.phoneNumber,
    this.coverImageUrl,
    this.galleryImages = const [],
    this.openingHours,
    this.instagramHandle,
    this.tiktokHandle,
    this.gender,
    this.birthDate,
    this.address,
    this.averageRating = 0.0,
    this.reviewCount = 0,
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
      blockedUsers: List<String>.from(data['blockedUsers'] ?? []),
      followers: List<String>.from(data['followers'] ?? []),
      following: List<String>.from(data['following'] ?? []),
      isGhost: data['isGhost'] ?? false,
      isPremium: data['isPremium'] ?? false,
      accountType: AccountType.values.firstWhere(
        (e) => e.name == (data['accountType'] ?? 'personal'),
        orElse: () => AccountType.personal,
      ),
      businessCategory: data['businessCategory'],
      website: data['website'],
      phoneNumber: data['phoneNumber'],
      coverImageUrl: data['coverImageUrl'],
      galleryImages: List<String>.from(data['galleryImages'] ?? []),
      openingHours: data['openingHours'],
      instagramHandle: data['instagramHandle'],
      tiktokHandle: data['tiktokHandle'],
      gender: data['gender'] != null  
          ? Gender.values.firstWhere((e) => e.name == data['gender'], orElse: () => Gender.other)
          : null,
      birthDate: data['birthDate'] != null ? (data['birthDate'] as Timestamp).toDate() : null,
      address: data['address'],
      averageRating: (data['averageRating'] ?? 0.0).toDouble(),
      reviewCount: data['reviewCount'] ?? 0,
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
      'blockedUsers': blockedUsers,
      'followers': followers,
      'following': following,
      'isGhost': isGhost,
      'isPremium': isPremium,
      'accountType': accountType.name,
      'businessCategory': businessCategory,
      'website': website,
      'phoneNumber': phoneNumber,
      'coverImageUrl': coverImageUrl,
      'galleryImages': galleryImages,
      'openingHours': openingHours,
      'instagramHandle': instagramHandle,
      'tiktokHandle': tiktokHandle,
      'gender': gender?.name,
      'birthDate': birthDate != null ? Timestamp.fromDate(birthDate!) : null,
      'address': address,
      'averageRating': averageRating,
      'reviewCount': reviewCount,
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
    List<String>? blockedUsers,
    List<String>? followers,
    List<String>? following,
    bool? isGhost,
    bool? isPremium,
    AccountType? accountType,
    String? businessCategory,
    String? website,
    String? phoneNumber,
    String? coverImageUrl,
    List<String>? galleryImages,
    String? openingHours,
    String? instagramHandle,
    String? tiktokHandle,
    Gender? gender,
    DateTime? birthDate,
    String? address,
    double? averageRating,
    int? reviewCount,
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
      blockedUsers: blockedUsers ?? this.blockedUsers,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      isGhost: isGhost ?? this.isGhost,
      isPremium: isPremium ?? this.isPremium,
      accountType: accountType ?? this.accountType,
      businessCategory: businessCategory ?? this.businessCategory,
      website: website ?? this.website,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      galleryImages: galleryImages ?? this.galleryImages,
      openingHours: openingHours ?? this.openingHours,
      instagramHandle: instagramHandle ?? this.instagramHandle,
      tiktokHandle: tiktokHandle ?? this.tiktokHandle,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      address: address ?? this.address,
      averageRating: averageRating ?? this.averageRating,
      reviewCount: reviewCount ?? this.reviewCount,
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

enum AccountType {
  personal,
  business,
}
