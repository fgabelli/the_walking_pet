import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/dog_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../shared/models/dog_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'profile_provider.dart'; // Import for storageServiceProvider

/// Dog Service Provider
final dogServiceProvider = Provider<DogService>((ref) {
  return DogService();
});

/// Dog Controller State
class DogState {
  final bool isLoading;
  final String? error;

  DogState({this.isLoading = false, this.error});
}

/// Dog Controller
class DogController extends StateNotifier<DogState> {
  final DogService _dogService;
  final StorageService _storageService;
  final Ref _ref;

  DogController(this._dogService, this._storageService, this._ref)
      : super(DogState());

  Future<void> createDog({
    required String name,
    required String breed,
    required int age,
    required DogSize size,
    required int energyLevel,
    required List<String> character,
    String? notes,
    File? imageFile,
    DogGender gender = DogGender.male,
  }) async {
    state = DogState(isLoading: true);
    try {
      final user = _ref.read(authServiceProvider).currentUser;
      if (user == null) throw Exception('User not authenticated');

      // 1. Create dog object with temporary ID
      final newDog = DogModel(
        id: '', // Will be updated with Firestore ID
        ownerId: user.uid,
        name: name,
        breed: breed,
        age: age,
        size: size,
        energyLevel: energyLevel,
        character: character,
        notes: notes,
        createdAt: DateTime.now(),
        gender: gender,
      );

      // 2. Create document in Firestore to get ID
      final dogId = await _dogService.createDog(newDog);

      // 3. Upload image if exists
      String? photoUrl;
      if (imageFile != null) {
        photoUrl = await _storageService.uploadDogProfileImage(dogId, imageFile);
      }

      // 4. Update dog with correct ID and Photo URL
      final updatedDog = newDog.copyWith(
        id: dogId,
        photoUrl: photoUrl,
      );
      await _dogService.updateDog(updatedDog);

      state = DogState(isLoading: false);
    } catch (e) {
      state = DogState(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateDog({
    required String id,
    required String name,
    required String breed,
    required int age,
    required DogSize size,
    required int energyLevel,
    required List<String> character,
    String? notes,
    File? imageFile,
    String? currentPhotoUrl,
    DogGender? gender,
  }) async {
    state = DogState(isLoading: true);
    try {
      final user = _ref.read(authServiceProvider).currentUser;
      if (user == null) throw Exception('User not authenticated');

      // 1. Upload new image if exists
      String? photoUrl = currentPhotoUrl;
      if (imageFile != null) {
        photoUrl = await _storageService.uploadDogProfileImage(id, imageFile);
      }

      // 2. Create updated dog object
      final updatedDog = DogModel(
        id: id,
        ownerId: user.uid,
        name: name,
        breed: breed,
        age: age,
        size: size,
        energyLevel: energyLevel,
        character: character,
        notes: notes,
        photoUrl: photoUrl,
        createdAt: DateTime.now(), // Ideally keep original creation date, but for now this is fine or we can pass it
        gender: gender ?? DogGender.male,
      );

      // 3. Update in Firestore
      await _dogService.updateDog(updatedDog);

      state = DogState(isLoading: false);
    } catch (e) {
      state = DogState(isLoading: false, error: e.toString());
    }
  }


  Future<void> deleteDog(String dogId) async {
    state = DogState(isLoading: true);
    try {
      await _dogService.deleteDog(dogId);
      state = DogState(isLoading: false);
    } catch (e) {
      state = DogState(isLoading: false, error: e.toString());
    }
  }
}

/// Dog Controller Provider
final dogControllerProvider = StateNotifierProvider<DogController, DogState>((ref) {
  return DogController(
    ref.watch(dogServiceProvider),
    ref.watch(storageServiceProvider),
    ref,
  );
});

