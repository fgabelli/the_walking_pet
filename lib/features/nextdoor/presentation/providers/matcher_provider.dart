import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/dog_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/map_service.dart';
import '../../../../core/services/matcher_service.dart';
import '../../../../core/services/user_service.dart';
import '../../../../shared/models/dog_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/models/chat_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../map/presentation/providers/map_provider.dart'; // contains locationServiceProvider
import '../../../profile/presentation/providers/dog_provider.dart'; // contains dogServiceProvider
import '../../../profile/presentation/providers/profile_provider.dart'; // contains userServiceProvider

class MatchResult {
  final DogModel userPet;
  final DogModel targetPet;
  final UserModel targetOwner;

  MatchResult({
    required this.userPet,
    required this.targetPet,
    required this.targetOwner,
  });
}

class MatcherState {
  final bool isLoading;
  final bool isSwiping;
  final String? error;
  
  final List<DogModel> userPets;
  final DogModel? selectedPet;
  
  final List<DogModel> availablePets;
  final Map<String, double> petDistances; // petId -> distance in km
  final Map<String, UserModel> petOwners; // ownerId -> Owner UserModel
  
  final List<PetSpecies> speciesFilter;
  final List<DogGender> genderFilter;
  final double maxDistanceFilter;
  final bool? isSterilizedFilter;
  
  final MatchResult? lastMatch;

  MatcherState({
    this.isLoading = false,
    this.isSwiping = false,
    this.error,
    this.userPets = const [],
    this.selectedPet,
    this.availablePets = const [],
    this.petDistances = const {},
    this.petOwners = const {},
    this.speciesFilter = const [PetSpecies.dog, PetSpecies.cat],
    this.genderFilter = const [DogGender.male, DogGender.female],
    this.maxDistanceFilter = 20.0,
    this.isSterilizedFilter,
    this.lastMatch,
  });

  MatcherState copyWith({
    bool? isLoading,
    bool? isSwiping,
    String? error,
    List<DogModel>? userPets,
    DogModel? selectedPet,
    List<DogModel>? availablePets,
    Map<String, double>? petDistances,
    Map<String, UserModel>? petOwners,
    List<PetSpecies>? speciesFilter,
    List<DogGender>? genderFilter,
    double? maxDistanceFilter,
    bool? isSterilizedFilter,
    MatchResult? lastMatch,
    bool clearLastMatch = false,
  }) {
    return MatcherState(
      isLoading: isLoading ?? this.isLoading,
      isSwiping: isSwiping ?? this.isSwiping,
      error: error ?? this.error,
      userPets: userPets ?? this.userPets,
      selectedPet: selectedPet ?? this.selectedPet,
      availablePets: availablePets ?? this.availablePets,
      petDistances: petDistances ?? this.petDistances,
      petOwners: petOwners ?? this.petOwners,
      speciesFilter: speciesFilter ?? this.speciesFilter,
      genderFilter: genderFilter ?? this.genderFilter,
      maxDistanceFilter: maxDistanceFilter ?? this.maxDistanceFilter,
      isSterilizedFilter: isSterilizedFilter ?? this.isSterilizedFilter,
      lastMatch: clearLastMatch ? null : (lastMatch ?? this.lastMatch),
    );
  }
}

class MatcherNotifier extends StateNotifier<MatcherState> {
  final Ref _ref;
  final DogService _dogService;
  final UserService _userService;
  final MatcherService _matcherService;
  final LocationService _locationService;
  final MapService _mapService;

  MatcherNotifier(this._ref)
      : _dogService = _ref.read(dogServiceProvider),
        _userService = _ref.read(userServiceProvider),
        _matcherService = _ref.read(matcherServiceProvider),
        _locationService = _ref.read(locationServiceProvider),
        _mapService = _ref.read(mapServiceProvider),
        super(MatcherState()) {
    _init();
  }

  /// Initial load of the user's own pets
  Future<void> _init() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = _ref.read(authServiceProvider).currentUser;
      if (user == null) {
        state = state.copyWith(isLoading: false, error: "Utente non autenticato");
        return;
      }

      final pets = await _dogService.getDogsByOwnerId(user.uid);
      if (pets.isNotEmpty) {
        state = state.copyWith(
          userPets: pets,
          selectedPet: pets.first,
        );
        // Load the swipe cards deck for the first pet
        await loadAvailablePets();
      } else {
        state = state.copyWith(
          userPets: [],
          selectedPet: null,
          availablePets: [],
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Change active pet
  Future<void> selectPet(DogModel pet) async {
    state = state.copyWith(selectedPet: pet, isLoading: true);
    await loadAvailablePets();
  }

  /// Update filters and reload deck
  Future<void> updateFilters({
    List<PetSpecies>? species,
    List<DogGender>? genders,
    double? maxDistance,
    bool? isSterilized,
  }) async {
    state = state.copyWith(
      speciesFilter: species ?? state.speciesFilter,
      genderFilter: genders ?? state.genderFilter,
      maxDistanceFilter: maxDistance ?? state.maxDistanceFilter,
      isSterilizedFilter: isSterilized ?? state.isSterilizedFilter,
      isLoading: true,
    );
    await loadAvailablePets();
  }

  /// Fetch and filter candidate pets
  Future<void> loadAvailablePets() async {
    final selectedPet = state.selectedPet;
    if (selectedPet == null) {
      state = state.copyWith(isLoading: false, availablePets: []);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final authUser = _ref.read(authServiceProvider).currentUser;
      if (authUser == null) throw Exception("Utente non autenticato");

      // 1. Get user position from user_locations (real-time GPS)
      double? lat;
      double? lng;
      
      final myLocation = await _mapService.getUserLocation(authUser.uid);
      if (myLocation != null) {
        lat = myLocation.latitude;
        lng = myLocation.longitude;
      } else {
        // Fallback: try profile home coords
        final currentUserProfile = await _userService.getUserById(authUser.uid);
        if (currentUserProfile != null && currentUserProfile.homeLatitude != null && currentUserProfile.homeLongitude != null) {
          lat = currentUserProfile.homeLatitude;
          lng = currentUserProfile.homeLongitude;
        } else {
          // Last resort: GPS
          try {
            final position = await _locationService.getCurrentPosition();
            lat = position.latitude;
            lng = position.longitude;
          } catch (_) {
            lat = 41.9028;
            lng = 12.4964;
          }
        }
      }

      // 2. Fetch already swiped pet IDs
      final swipedIds = await _matcherService.getSwipedPetIds(selectedPet.id);

      // 3. Search dogs based on filters
      final searchResults = await _dogService.searchDogs(
        species: state.speciesFilter,
        genders: state.genderFilter,
        limit: 100,
      );

      // 4. Filter and compute distances
      final List<DogModel> filteredPets = [];
      final Map<String, double> distances = {};
      final Map<String, UserModel> owners = {};
      // Cache user locations to avoid re-fetching for owners with multiple pets
      final Map<String, UserLocation?> ownerLocations = {};

      for (final pet in searchResults) {
        // Exclude own pets
        if (pet.ownerId == authUser.uid) continue;
        // Exclude already swiped pets
        if (swipedIds.contains(pet.id)) continue;

        // Fetch owner info
        UserModel? owner = owners[pet.ownerId];
        if (owner == null) {
          owner = await _userService.getUserById(pet.ownerId);
          if (owner != null) {
            owners[pet.ownerId] = owner;
          }
        }

        if (owner == null) continue;

        // Get owner's real-time location from user_locations
        if (!ownerLocations.containsKey(pet.ownerId)) {
          ownerLocations[pet.ownerId] = await _mapService.getUserLocation(pet.ownerId);
        }
        final ownerLocation = ownerLocations[pet.ownerId];

        // Calculate distance using real GPS coordinates
        double distanceKm = 0.0;
        if (ownerLocation != null && lat != null && lng != null) {
          final distMeters = _locationService.calculateDistance(
            lat,
            lng,
            ownerLocation.latitude,
            ownerLocation.longitude,
          );
          distanceKm = distMeters / 1000.0;
        }

        // Apply distance filter
        if (distanceKm <= state.maxDistanceFilter) {
          // Apply sterilized filter
          if (state.isSterilizedFilter != null && pet.isSterilized != state.isSterilizedFilter) {
            continue;
          }
          filteredPets.add(pet);
          distances[pet.id] = distanceKm;
        }
      }

      state = state.copyWith(
        isLoading: false,
        availablePets: filteredPets,
        petDistances: distances,
        petOwners: owners,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Perform swipe
  Future<void> swipe({required String targetPetId, required bool isLike}) async {
    final selectedPet = state.selectedPet;
    if (selectedPet == null) return;

    final targetPet = state.availablePets.firstWhere((p) => p.id == targetPetId);
    final targetOwner = state.petOwners[targetPet.ownerId];

    // Remove swiped pet from the deck locally first for immediate UI feedback
    final updatedList = List<DogModel>.from(state.availablePets)..removeWhere((p) => p.id == targetPetId);
    state = state.copyWith(availablePets: updatedList);

    try {
      final user = _ref.read(authServiceProvider).currentUser;
      if (user == null) return;

      final isMatch = await _matcherService.swipePet(
        senderPetId: selectedPet.id,
        targetPetId: targetPetId,
        senderUid: user.uid,
        targetUid: targetPet.ownerId,
        isLike: isLike,
      );

      if (isMatch && targetOwner != null) {
        // Auto-create chat on match (implicit consent)
        try {
          final chatController = _ref.read(chatControllerProvider.notifier);
          await chatController.createChat(targetPet.ownerId, initialStatus: ChatStatus.accepted);
        } catch (e) {
          debugPrint('Error auto-creating chat on match: $e');
        }

        // Trigger Match overlay
        state = state.copyWith(
          lastMatch: MatchResult(
            userPet: selectedPet,
            targetPet: targetPet,
            targetOwner: targetOwner,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving swipe: $e');
    }
  }

  /// Get list of liked pets (for history view)
  Future<List<DogModel>> getLikedPets() async {
    final selectedPet = state.selectedPet;
    if (selectedPet == null) return [];

    try {
      final likedIds = await _matcherService.getLikedPetIds(selectedPet.id);
      final List<DogModel> likedPets = [];

      for (final petId in likedIds) {
        final pet = await _dogService.getDogById(petId);
        if (pet != null) likedPets.add(pet);
      }

      return likedPets;
    } catch (e) {
      debugPrint('Error loading liked pets: $e');
      return [];
    }
  }

  /// Get list of pets that have liked us (received likes)
  Future<List<DogModel>> getReceivedLikes() async {
    final selectedPet = state.selectedPet;
    if (selectedPet == null) return [];

    try {
      final receivedIds = await _matcherService.getReceivedLikesPetIds(selectedPet.id);
      final List<DogModel> receivedPets = [];

      for (final petId in receivedIds) {
        final pet = await _dogService.getDogById(petId);
        if (pet != null) receivedPets.add(pet);
      }

      return receivedPets;
    } catch (e) {
      debugPrint('Error loading received likes: $e');
      return [];
    }
  }

  /// Clear the active match overlay
  void clearMatch() {
    state = state.copyWith(clearLastMatch: true);
  }
}

final matcherProvider = StateNotifierProvider<MatcherNotifier, MatcherState>((ref) {
  return MatcherNotifier(ref);
});
