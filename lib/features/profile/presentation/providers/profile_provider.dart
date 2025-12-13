import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/user_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/review_service.dart';
import '../../../../core/services/safety_service.dart';
import '../../../../core/services/sos_service.dart'; // Added
import '../../../../shared/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

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

/// SOS Service Provider
final sosServiceProvider = Provider<SOSService>((ref) {
  return SOSService();
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
    error: (_, __) => Stream.value(null),
  );
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
  final Ref _ref;

  ProfileController(this._userService, this._storageService, this._ref)
      : super(ProfileState());

  Future<void> createProfile({
    required String firstName,
    required String lastName,
    required String zone,
    File? imageFile,
    String? bio,
    Gender? gender,
    DateTime? birthDate,
    String? address,
  }) async {
    state = ProfileState(isLoading: true);
    try {
      final user = _ref.read(authServiceProvider).currentUser;
      if (user == null) throw Exception('User not authenticated');

      String? photoUrl;
      if (imageFile != null) {
        photoUrl = await _storageService.uploadUserProfileImage(user.uid, imageFile);
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
    File? coverImageFile, // Added
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

      final updatedUser = currentUserProfile.copyWith(
        firstName: firstName,
        lastName: lastName,
        zone: zone,
        bio: bio,
        photoUrl: photoUrl,
        coverImageUrl: coverImageUrl, // Added
        socialPreferences: socialPreferences,
        updatedAt: DateTime.now(),
        gender: gender,
        birthDate: birthDate,
        address: address,
        accountType: accountType,
        businessCategory: businessCategory,
        website: website,
        phoneNumber: phoneNumber,
        instagramHandle: instagramHandle,
        tiktokHandle: tiktokHandle,
        openingHours: openingHours,
      );

      await _userService.updateUser(updatedUser);
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

      // 1. Delete user data from Firestore
      await _userService.deleteUser(user.uid);

      // 2. Delete user from Auth
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
    ref,
  );
});
