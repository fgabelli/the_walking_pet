import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import '../../../../core/services/user_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/review_service.dart';
import '../../../../core/services/safety_service.dart';
import '../../../../core/services/purchase_service.dart'; // Added
import '../../../../core/services/map_service.dart'; // Added
import '../../../../core/services/osm_service.dart';
import '../../../../shared/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'dog_provider.dart';

/// User Service Provider
final userServiceProvider = Provider<UserService>((ref) {
  return UserService();
});

/// Storage Service Provider
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final reviewServiceProvider = Provider<ReviewService>((ref) {
  return ReviewService();
});

/// Safety Service Provider
final safetyServiceProvider = Provider<SafetyService>((ref) {
  return SafetyService();
});



/// Current User Profile Provider
final currentUserProfileProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref.watch(userServiceProvider).getUserStream(user.uid);
    },
    loading: () => Stream.value(null),
    error: (e, st) => Stream.value(null),
  );
});

/// Stream provider for specific user profile
final userProfileStreamProvider = StreamProvider.family<UserModel?, String>((ref, uid) {
  return ref.watch(userServiceProvider).getUserStream(uid);
});

/// Profile Controller State
class ProfileState {
  final bool isLoading;
  final String? error;

  ProfileState({this.isLoading = false, this.error});
}

/// Profile Controller
class ProfileController extends StateNotifier<ProfileState> {
  final UserService _userService;
  final StorageService _storageService;
  final PurchaseService _purchaseService;
  final Ref _ref;

  ProfileController(this._userService, this._storageService, this._purchaseService, this._ref)
      : super(ProfileState()) {
    _initPurchases();
  }

  Future<void> _initPurchases() async {
     await _purchaseService.init();
     
     // Ensure user is identified if already logged in
     final user = _ref.read(authServiceProvider).currentUser;
     if (user != null) {
       await _purchaseService.identifyUser(user.uid);
     }
     
     await refreshEntitlements();
  }

  Future<void> refreshEntitlements() async {
    final customerInfo = await _purchaseService.getCustomerInfo();
    if (customerInfo != null) {
      final isPremium = _purchaseService.isPremium(customerInfo);
      final isBusiness = _purchaseService.isBusiness(customerInfo);
      
      // Sync with Firestore if changed (Optimistic check)
      final user = _ref.read(authServiceProvider).currentUser;
      if (user != null) {
         final currentUserProfile = await _userService.getUserById(user.uid);
         if (currentUserProfile != null) {
           bool needsUpdate = false;
           UserModel updatedUser = currentUserProfile;

           // Sync Premium
           if (currentUserProfile.isPremium != isPremium) {
             updatedUser = updatedUser.copyWith(isPremium: isPremium);
             needsUpdate = true;
           }

           // Sync Business (Unlock if entitled, but don't downgrade automatically maybe? 
           // Or yes, strict sync? Let's be strict for now or add logic to not downgrade business if manual override is present?
           // For simplicity: If has business entitlement, force business type.
           if (isBusiness) {
             if (currentUserProfile.accountType != AccountType.business) {
                updatedUser = updatedUser.copyWith(accountType: AccountType.business);
                needsUpdate = true;
             }
           } 
           // If NOT business entitlement, should we downgrade? 
           // Maybe they cancelled. Yes, let's revert to personal if not entitled.
           else if (currentUserProfile.accountType == AccountType.business) {
              // CAREFUL: What if they are grandfathered? 
              // For this task, we assume strict sync.
              updatedUser = updatedUser.copyWith(accountType: AccountType.personal);
              needsUpdate = true;
           }
           
           if (needsUpdate) {
             await _userService.updateUser(updatedUser);
           }
         }
      }
    }
  }

  Future<void> createProfile({
    required String firstName,
    required String lastName,
    required String zone,
    File? imageFile,
    String? bio,
    Gender? gender,
    DateTime? birthDate,
    String? address,
    String mapMarkerId = 'default', // Added
  }) async {
    state = ProfileState(isLoading: true);
    try {
      final user = _ref.read(authServiceProvider).currentUser;
      if (user == null) throw Exception('User not authenticated');

      String? photoUrl;
      if (imageFile != null) {
        photoUrl = await _storageService.uploadUserProfileImage(user.uid, imageFile);
      }

      double? homeLatitude;
      double? homeLongitude;
      String? city;
      String? province;
      String? region;
      String? country;
      final geocodeQuery = (address != null && address.isNotEmpty) ? address : zone;
      if (geocodeQuery.isNotEmpty) {
        try {
          final locations = await locationFromAddress('$geocodeQuery, Italia');
          if (locations.isNotEmpty) {
            homeLatitude = locations.first.latitude;
            homeLongitude = locations.first.longitude;
            
            // Sync with MapService for Radar/Discovery (even if offline)
            try {
               await MapService().updateUserLocation(
                 user.uid, 
                 homeLatitude!, 
                 homeLongitude!
               );
            } catch (e) {
               print('Error syncing map location: $e');
            }

            // Reverse geocode using OSM Nominatim to populate structured fields
            try {
              final osmData = await OSMService().reverseGeocode(homeLatitude!, homeLongitude!);
              if (osmData != null) {
                city = osmData['city'] ?? zone;
                province = osmData['province'];
                region = osmData['region'];
                country = osmData['country'] ?? 'Italia';
              } else {
                city = zone;
                country = 'Italia';
              }
            } catch (e) {
              print('Reverse geocoding error during profile creation: $e');
              city = zone;
              country = 'Italia';
            }
          }
        } catch (e) {
          print('Geocoding error during profile creation: $e');
        }
      }

      final newUser = UserModel(
        uid: user.uid,
        firstName: firstName,
        lastName: lastName,
        email: user.email ?? '',
        photoUrl: photoUrl ?? user.photoURL,
        bio: bio,
        zone: zone,
        socialPreferences: SocialPreferences(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        gender: gender,
        birthDate: birthDate,
        address: address,
        homeLatitude: homeLatitude,
        homeLongitude: homeLongitude,
        city: city,
        province: province,
        region: region,
        country: country,
        mapMarkerId: mapMarkerId, // Added
      );

      await _userService.createUser(newUser);
      state = ProfileState(isLoading: false);
    } catch (e) {
      state = ProfileState(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? zone,
    String? bio,
    File? imageFile,
    File? coverImageFile,
    SocialPreferences? socialPreferences,
    Gender? gender,
    DateTime? birthDate,
    String? address,
    String? businessCategory,
    String? website,
    String? phoneNumber,
    AccountType? accountType,
    String? instagramHandle,
    String? tiktokHandle,
    String? openingHours,
    String? mapMarkerId, // Added
    bool? isGhost,
  }) async {
    state = ProfileState(isLoading: true);
    try {
      final user = _ref.read(authServiceProvider).currentUser;
      if (user == null) throw Exception('User not authenticated');

      final currentUserProfile = await _userService.getUserById(user.uid);
      if (currentUserProfile == null) throw Exception('Profile not found');

      String? photoUrl = currentUserProfile.photoUrl;
      if (imageFile != null) {
        photoUrl = await _storageService.uploadUserProfileImage(user.uid, imageFile);
      }

      String? coverImageUrl = currentUserProfile.coverImageUrl;
      if (coverImageFile != null) {
        coverImageUrl = await _storageService.uploadUserCoverImage(user.uid, coverImageFile);
      }

      double? homeLatitude = currentUserProfile.homeLatitude;
      double? homeLongitude = currentUserProfile.homeLongitude;
      String? city = currentUserProfile.city;
      String? province = currentUserProfile.province;
      String? region = currentUserProfile.region;
      String? country = currentUserProfile.country;

      bool shouldGeocode = false;
      String? targetAddress;

      if (address != null && address != currentUserProfile.address) {
        if (address.isEmpty) {
          final effectiveZone = zone ?? currentUserProfile.zone;
          if (effectiveZone.isNotEmpty) {
            targetAddress = effectiveZone;
            shouldGeocode = true;
          } else {
            homeLatitude = null;
            homeLongitude = null;
            city = null;
            province = null;
            region = null;
            country = null;
          }
        } else {
          targetAddress = address;
          shouldGeocode = true;
        }
      } else if (zone != null && zone != currentUserProfile.zone && (address ?? currentUserProfile.address ?? '').isEmpty) {
        if (zone.isNotEmpty) {
          targetAddress = zone;
          shouldGeocode = true;
        }
      }

      if (shouldGeocode && targetAddress != null) {
        try {
          final locations = await locationFromAddress('$targetAddress, Italia');
          if (locations.isNotEmpty) {
            homeLatitude = locations.first.latitude;
            homeLongitude = locations.first.longitude;
            
            // Sync with MapService for Radar/Discovery
            try {
               await MapService().updateUserLocation(
                 user.uid, 
                 homeLatitude!, 
                 homeLongitude!
               );
            } catch (e) {
               print('Error syncing map location: $e');
            }

            // Reverse geocode using OSM Nominatim to populate structured fields
            try {
              final osmData = await OSMService().reverseGeocode(homeLatitude!, homeLongitude!);
              if (osmData != null) {
                city = osmData['city'] ?? (zone ?? currentUserProfile.zone);
                province = osmData['province'];
                region = osmData['region'];
                country = osmData['country'] ?? 'Italia';
              } else {
                city = zone ?? currentUserProfile.zone;
                country = 'Italia';
              }
            } catch (e) {
              print('Reverse geocoding error during profile update: $e');
              city = zone ?? currentUserProfile.zone;
              country = 'Italia';
            }
          }
        } catch (e) {
          print('Geocoding error during profile update: $e');
        }
      }

      final updatedUser = currentUserProfile.copyWith(
        firstName: firstName,
        lastName: lastName,
        zone: zone,
        bio: bio,
        photoUrl: photoUrl,
        coverImageUrl: coverImageUrl,
        socialPreferences: socialPreferences,
        updatedAt: DateTime.now(),
        gender: gender,
        birthDate: birthDate,
        address: address,
        homeLatitude: homeLatitude,
        homeLongitude: homeLongitude,
        city: city,
        province: province,
        region: region,
        country: country,
        accountType: accountType,
        businessCategory: businessCategory,
        website: website,
        phoneNumber: phoneNumber,
        instagramHandle: instagramHandle,
        tiktokHandle: tiktokHandle,
        openingHours: openingHours,
        mapMarkerId: mapMarkerId, // Added
        isGhost: isGhost,
      );

      await _userService.updateUser(updatedUser);
      state = ProfileState(isLoading: false);
    } catch (e) {
      state = ProfileState(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateLocationPrivacy({
    required LocationPrivacy privacy,
    List<String>? whitelist,
  }) async {
    state = ProfileState(isLoading: true);
    try {
      final user = _ref.read(authServiceProvider).currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _userService.updateLocationPrivacy(
        user.uid,
        privacy: privacy,
        whitelist: whitelist,
      );
      state = ProfileState(isLoading: false);
    } catch (e) {
      state = ProfileState(isLoading: false, error: e.toString());
    }
  }

  Future<void> deleteAccount() async {
    state = ProfileState(isLoading: true);
    try {
      final user = _ref.read(authServiceProvider).currentUser;
      if (user == null) throw Exception('User not authenticated');

      // 1. Delete user's dogs from Firestore
      try {
        final dogService = _ref.read(dogServiceProvider);
        final dogs = await dogService.getDogsByOwnerId(user.uid);
        for (final dog in dogs) {
          await dogService.deleteDog(dog.id);
        }
      } catch (e) {
        print('Error deleting user dogs during account deletion: $e');
      }

      // 2. Delete user data from Firestore
      await _userService.deleteUser(user.uid);

      // 3. Delete user from Auth
      await _ref.read(authServiceProvider).deleteAccount();

      // 3. Sign out
      await _ref.read(authServiceProvider).signOut();
      
      state = ProfileState(isLoading: false);
    } catch (e) {
      state = ProfileState(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}



/// Profile Controller Provider
final profileControllerProvider = StateNotifierProvider<ProfileController, ProfileState>((ref) {
  return ProfileController(
    ref.watch(userServiceProvider),
    ref.watch(storageServiceProvider),
    ref.watch(purchaseServiceProvider), // Injected
    ref,
  );
});

/// Provider to fetch multiple users by ID
final usersByIdsProvider = FutureProvider.family<List<UserModel>, List<String>>((ref, ids) async {
  if (ids.isEmpty) return [];
  final userService = ref.read(userServiceProvider);
  final List<UserModel> users = [];
  for (final id in ids) {
    final user = await userService.getUserById(id);
    if (user != null) users.add(user);
  }
  return users;
});
