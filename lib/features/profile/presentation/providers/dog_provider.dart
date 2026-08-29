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
    PetSpecies species = PetSpecies.dog,
    double? weight,
    String? microchipNumber,
    String? bloodType,
    bool isSterilized = false,
    List<String> existingMediaUrls = const [],
    List<File> newMediaFiles = const [],
  }) async {
    state = DogState(isLoading: true);
    try {
      final user = _ref.read(authServiceProvider).currentUser;
      if (user == null) throw Exception('User not authenticated');

      // 1. Crea l'oggetto dog con ID temporaneo
      final newDog = DogModel(
        id: '', // Verrà aggiornato con l'ID Firestore
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
        species: species,
        weight: weight,
        microchipNumber: microchipNumber,
        bloodType: bloodType,
        isSterilized: isSterilized,
      );

      // 2. Crea il documento in Firestore per ottenere l'ID
      final dogId = await _dogService.createDog(newDog);

      // 3. Upload media files
      final allMediaUrls = [...existingMediaUrls];

      if (newMediaFiles.isNotEmpty) {
        // Upload nuovi file media nella gallery
        for (int i = 0; i < newMediaFiles.length; i++) {
          final url = await _storageService.uploadDogMediaImage(
            dogId, newMediaFiles[i], allMediaUrls.length + i,
          );
          allMediaUrls.add(url);
        }
      } else if (imageFile != null) {
        // Backward compat: vecchio parametro imageFile singolo
        final url = await _storageService.uploadDogProfileImage(dogId, imageFile);
        allMediaUrls.add(url);
      }

      // 4. Aggiorna il dog con ID corretto e media URLs
      final updatedDog = newDog.copyWith(
        id: dogId,
        mediaUrls: allMediaUrls,
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
    PetSpecies? species,
    double? weight,
    String? microchipNumber,
    String? bloodType,
    bool isSterilized = false,
    List<String> existingMediaUrls = const [],
    List<File> newMediaFiles = const [],
  }) async {
    state = DogState(isLoading: true);
    try {
      final user = _ref.read(authServiceProvider).currentUser;
      if (user == null) throw Exception('User not authenticated');

      // 1. Costruisci la lista media URLs partendo da quelle esistenti
      final allMediaUrls = [...existingMediaUrls];

      // Backward compat: se non ci sono existingMediaUrls ma c'è currentPhotoUrl
      if (allMediaUrls.isEmpty && currentPhotoUrl != null) {
        allMediaUrls.add(currentPhotoUrl);
      }

      // 2. Upload nuovi file media
      if (newMediaFiles.isNotEmpty) {
        for (int i = 0; i < newMediaFiles.length; i++) {
          final url = await _storageService.uploadDogMediaImage(
            id, newMediaFiles[i], allMediaUrls.length + i,
          );
          allMediaUrls.add(url);
        }
      } else if (imageFile != null) {
        // Backward compat: vecchio parametro imageFile singolo
        final url = await _storageService.uploadDogProfileImage(id, imageFile);
        // Sostituisci la prima URL se presente, altrimenti aggiungi
        if (allMediaUrls.isNotEmpty) {
          allMediaUrls[0] = url;
        } else {
          allMediaUrls.add(url);
        }
      }

      // 3. Crea l'oggetto dog aggiornato
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
        mediaUrls: allMediaUrls,
        createdAt: DateTime.now(), // Idealmente mantenere la data originale
        gender: gender ?? DogGender.male,
        species: species ?? PetSpecies.dog,
        weight: weight,
        microchipNumber: microchipNumber,
        bloodType: bloodType,
        isSterilized: isSterilized,
      );

      // 4. Aggiorna in Firestore
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

/// Fetch a single dog by its Firestore document ID
final dogByIdProvider = FutureProvider.family<DogModel?, String>((ref, dogId) async {
  if (dogId.isEmpty) return null;
  return ref.watch(dogServiceProvider).getDogById(dogId);
});
