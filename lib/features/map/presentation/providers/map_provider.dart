import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/map_service.dart';
import '../../../../core/services/user_service.dart';
import '../../../../core/services/sos_service.dart'; // Added
import '../../../../core/services/event_service.dart'; // Added
import '../../../../shared/models/user_model.dart';
import '../../../../shared/models/event_model.dart'; // Added
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../walks/presentation/providers/walk_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../../shared/models/walk_model.dart';
import '../../../../shared/models/announcement_model.dart';
import '../../../../shared/models/safety_alert_model.dart';
import '../../../../shared/models/lost_pet_alert_model.dart'; // Added
import '../../../nextdoor/presentation/providers/nextdoor_provider.dart';
import '../../../../shared/models/dog_model.dart';
import '../../../../core/services/dog_service.dart';

/// Location Service Provider
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// Map Service Provider
final mapServiceProvider = Provider<MapService>((ref) {
  return MapService();
});

/// Dog Service Provider
final dogServiceProvider = Provider<DogService>((ref) {
  return DogService();
});

/// Map State
class MapState {
  final Position? currentPosition;
  final List<Marker> markers;
  final bool isLoading;
  final String? error;
  final bool isLocationEnabled;
  final bool isMocked;
  final UserModel? selectedUser;
  final String searchQuery;
  final List<UserLocation> allUserLocations;
  final List<WalkModel> allWalks;
  final List<AnnouncementModel> allAnnouncements;
  final List<SafetyAlertModel> allAlerts;
  final List<LostPetAlertModel> allSOSAlerts; // Added
  final List<EventModel> allEvents; // Added
  final WalkModel? selectedWalk;
  final AnnouncementModel? selectedAnnouncement;
  final SafetyAlertModel? selectedAlert;
  final LostPetAlertModel? selectedSOS; // Added
  final EventModel? selectedEvent; // Added
  final List<String> blockedUsers;
  // Filters
  // User Filters
  final String? filterBreed; // Legacy/User-based? Or reuse for Dog Breed? Let's use specific ones.
  final Gender? filterGender; // User Gender
  final PetSpecies? filterPetSpecies; // Added: Global Species Filter (Free)
  
  // Dog Compatibility Filters (Premium)
  final Map<String, List<DogModel>> dogCache; // ownerId -> List<DogModel>
  final List<DogSize> filterDogSizes;
  final List<DogGender> filterDogGenders;
  final List<String> filterDogBreeds;

  final bool isGhostModeEnabled; // Local user setting state

  MapState({
    this.currentPosition,
    this.markers = const [],
    this.isLoading = true,
    this.error,
    this.isLocationEnabled = false,
    this.isMocked = false,
    this.selectedUser,
    this.searchQuery = '',
    this.allUserLocations = const [],
    this.allWalks = const [],
    this.allAnnouncements = const [],
    this.allAlerts = const [],
    this.allSOSAlerts = const [],
    this.allEvents = const [],
    this.selectedWalk,
    this.selectedAnnouncement,
    this.selectedAlert,
    this.selectedSOS,
    this.selectedEvent,
    this.blockedUsers = const [],
    this.filterBreed,
    this.filterGender,
    this.filterPetSpecies, // Added
    this.dogCache = const {},
    this.filterDogSizes = const [],
    this.filterDogGenders = const [],
    this.filterDogBreeds = const [],
    this.isGhostModeEnabled = false,
  });

  MapState copyWith({
    Position? currentPosition,
    List<Marker>? markers,
    bool? isLoading,
    String? error,
    bool? isLocationEnabled,
    bool? isMocked,
    UserModel? selectedUser,
    String? searchQuery,
    List<UserLocation>? allUserLocations,
    List<WalkModel>? allWalks,
    List<AnnouncementModel>? allAnnouncements,
    List<SafetyAlertModel>? allAlerts,
    List<LostPetAlertModel>? allSOSAlerts,
    List<EventModel>? allEvents,
    WalkModel? selectedWalk,
    AnnouncementModel? selectedAnnouncement,
    SafetyAlertModel? selectedAlert,
    LostPetAlertModel? selectedSOS,
    EventModel? selectedEvent,
    List<String>? blockedUsers,
    String? filterBreed,
    Gender? filterGender,
    PetSpecies? filterPetSpecies, // Added
    Map<String, List<DogModel>>? dogCache,
    List<DogSize>? filterDogSizes,
    List<DogGender>? filterDogGenders,
    List<String>? filterDogBreeds,
    bool? isGhostModeEnabled,
  }) {
    return MapState(
      currentPosition: currentPosition ?? this.currentPosition,
      markers: markers ?? this.markers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isLocationEnabled: isLocationEnabled ?? this.isLocationEnabled,
      isMocked: isMocked ?? this.isMocked,
      selectedUser: selectedUser,
      searchQuery: searchQuery ?? this.searchQuery,
      allUserLocations: allUserLocations ?? this.allUserLocations,
      allWalks: allWalks ?? this.allWalks,
      allAnnouncements: allAnnouncements ?? this.allAnnouncements,
      allAlerts: allAlerts ?? this.allAlerts,
      allSOSAlerts: allSOSAlerts ?? this.allSOSAlerts,
      allEvents: allEvents ?? this.allEvents,
      selectedWalk: selectedWalk,
      selectedAnnouncement: selectedAnnouncement,
      selectedAlert: selectedAlert,
      selectedSOS: selectedSOS,
      selectedEvent: selectedEvent,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      filterBreed: filterBreed ?? this.filterBreed,
      filterGender: filterGender ?? this.filterGender,
      filterPetSpecies: filterPetSpecies ?? this.filterPetSpecies, // Added
      dogCache: dogCache ?? this.dogCache,
      filterDogSizes: filterDogSizes ?? this.filterDogSizes,
      filterDogGenders: filterDogGenders ?? this.filterDogGenders,
      filterDogBreeds: filterDogBreeds ?? this.filterDogBreeds,
      isGhostModeEnabled: isGhostModeEnabled ?? this.isGhostModeEnabled,
    );
  }
}

/// Map Controller
class MapStateController extends StateNotifier<MapState> {
  final LocationService _locationService;
  final LocationService _locationService;
  final MapService _mapService;
  final UserService _userService;
  final DogService _dogService; // Added
  final Ref _ref;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<List<UserLocation>>? _nearbyUsersSubscription;
  StreamSubscription<List<WalkModel>>? _walksSubscription;
  StreamSubscription<List<AnnouncementModel>>? _announcementsSubscription;
  StreamSubscription<List<SafetyAlertModel>>? _alertsSubscription;
  StreamSubscription<List<LostPetAlertModel>>? _sosSubscription; // Added
  StreamSubscription<List<EventModel>>? _eventsSubscription; // Added

  MapStateController(
    this._locationService,
    this._mapService,
    this._userService,
    this._ref,
  ) : super(MapState()) {
    _initLocation();
    _startListeningToWalks();
    _startListeningToProfile();
    _startListeningToAlerts();
    _startListeningToSOS(); // Added
    _startListeningToEvents(); // Added
  }

  MapStateController(
    this._locationService,
    this._mapService,
    this._userService,
    this._dogService,
    this._ref,
  ) : super(MapState()) {
    _initLocation();
    _startListeningToWalks();
    _startListeningToProfile();
    _startListeningToAlerts();
    _startListeningToSOS(); 
    _startListeningToEvents(); 
  }

  void _startListeningToEvents() {
    _eventsSubscription = _ref.read(eventServiceProvider).getUpcomingEventsStream().listen(
      (events) {
        state = state.copyWith(allEvents: events);
        _updateMarkers();
      },
      onError: (e) {
        print('Error fetching events: $e');
      },
    );
  }

  
  void _startListeningToProfile() {
    _ref.listen(currentUserProfileProvider, (previous, next) {
      next.whenData((user) {
        if (user != null) {
          state = state.copyWith(
            blockedUsers: user.blockedUsers,
            isGhostModeEnabled: user.isGhost,
          );
          _updateMarkers(); 
        }
      });
    });
  }

  void _startListeningToWalks() {
    _walksSubscription = _ref.read(walkServiceProvider).getUpcomingWalks().listen(
      (walks) {
        state = state.copyWith(allWalks: walks);
        _updateMarkers();
      },
      onError: (e) {
        print('Error fetching walks: $e');
      },
    );
  }

  void _startListeningToAlerts() {
    _alertsSubscription = _ref.read(safetyServiceProvider).getActiveAlertsStream().listen(
      (alerts) {
        state = state.copyWith(allAlerts: alerts);
        _updateMarkers();
      },
      onError: (e) {
        print('Error fetching alerts: $e');
      },
    );
  }

  // LISTEN TO SOS ALERTS (ADDED)
  void _startListeningToSOS() {
    _sosSubscription = _ref.read(sosServiceProvider).getActiveSOSStream().listen(
      (alerts) {
        state = state.copyWith(allSOSAlerts: alerts);
        _updateMarkers();
      },
      onError: (e) {
        print('Error fetching SOS: $e');
      },
    );
  }

  void _startListeningToAnnouncements(Position center) {
    _announcementsSubscription?.cancel();
    _announcementsSubscription = _ref.read(nextdoorServiceProvider).getNearbyAnnouncements(
      latitude: center.latitude,
      longitude: center.longitude,
      radiusInKm: 10.0,
    ).listen(
      (announcements) {
        final activeAnnouncements = announcements.where((a) => a.isActive).toList();
        state = state.copyWith(allAnnouncements: activeAnnouncements);
        _updateMarkers();
      },
      onError: (e) {
        print('Error fetching announcements: $e');
      },
    );
  }

  Future<void> _initLocation() async {
    try {
      final isEnabled = await _locationService.isLocationServiceEnabled();
      if (!isEnabled) {
        state = state.copyWith(
          isLoading: false,
          isLocationEnabled: false,
          error: 'Servizi di localizzazione disabilitati',
        );
        return;
      }

      final hasPermission = await _locationService.requestPermission();
      if (!hasPermission) {
        state = state.copyWith(
          isLoading: false,
          isLocationEnabled: false,
          error: 'Permessi di localizzazione negati',
        );
        return;
      }

      state = state.copyWith(isLocationEnabled: true);

      // STRATEGY: 
      // 1. Try Last Known Position (Fastest) to show something immediately
      final lastKnown = await _locationService.getLastKnownPosition();
      if (lastKnown != null) {
        print('Using Last Known Position: ${lastKnown.latitude}, ${lastKnown.longitude}');
        _updatePosition(lastKnown);
        // Don't turn off loading yet if we want to wait for fresh, 
        // but often it's better to show map immediately.
      }

      // 2. Start Listening (Best for updates)
      // We start listening immediately so we catch the fresh fix whenever it comes
      _positionSubscription = _locationService.getPositionStream().listen(
        (position) {
          print('Position update: ${position.latitude}, ${position.longitude}');
          _updatePosition(position);
        },
        onError: (e) {
          print('Position stream error: $e');
          // Only show error if we have NO position at all
          if (state.currentPosition == null) {
            state = state.copyWith(error: e.toString(), isLoading: false);
          }
        },
      );

      // 3. If no last known, try to urge a current position fetch
      if (lastKnown == null) {
        try {
          // Allow the service to handle the time limit
          final position = await _locationService.getCurrentPosition();
          _updatePosition(position);
        } catch (e) {
           // If stream hasn't picked up yet, show the specific error
           if (state.currentPosition == null) {
              String errorMsg = 'Impossibile rilevare la posizione GPS.';
              if (e.toString().contains('disabilitati')) {
                errorMsg = 'Attiva il GPS nelle impostazioni.';
              } else if (e.toString().contains('negati')) {
                errorMsg = 'Permessi GPS necessari.';
              } else if (e.toString().contains('Timeout')) {
                errorMsg = 'Segnale GPS debole o assente.';
              }
              state = state.copyWith(isLoading: false, error: errorMsg);
           }
        }
      } 
      
      // Ensure loading is off eventually
      if (state.currentPosition != null) {
         state = state.copyWith(isLoading: false);
      }

    } catch (e) {
      print('Error initializing location: $e');
      state = state.copyWith(isLoading: false, error: 'Errore GPS: $e');
    }
  }

  void _updatePosition(Position position) {
    state = state.copyWith(
      currentPosition: position,
      isMocked: position.isMocked,
      isLoading: false,
    );

    // Update user location in Firestore
    final user = _ref.read(authServiceProvider).currentUser;
    if (user != null) {
      _mapService.updateUserLocation(
        user.uid,
        position.latitude,
        position.longitude,
      );

      // Fetch nearby users if not already listening
      if (_nearbyUsersSubscription == null) {
        _startListeningToNearbyUsers(position);
      }
      
      // Fetch nearby announcements if not already listening
      if (_announcementsSubscription == null) {
        _startListeningToAnnouncements(position);
      }
    }
  }

  // Cache for user profiles to avoid re-fetching and allow filtering
  final Map<String, UserModel> _userCache = {};
  List<UserLocation> _currentUserLocations = [];
  // We need to store walks too if we want to filter them
  // For now let's focus on users or fetch walks inside the listener

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _updateMarkers();
  }

  void setFilters({String? breed, Gender? gender}) {
    state = state.copyWith(
      filterBreed: breed,
      filterGender: gender,
    );
    _updateMarkers();
  }
  
  void clearFilters() {
    state = state.copyWith(
      filterBreed: null,
      filterGender: null,
    );
    _updateMarkers();
  }

  Future<void> toggleGhostMode(bool enabled) async {
    final user = _ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    
    // Optimistic update
    state = state.copyWith(isGhostModeEnabled: enabled);
    
    try {
      await _userService.updateUserFields(user.uid, {'isGhost': enabled});
      // The profile listener will confirm the state update
    } catch (e) {
      print('Error toggling ghost mode: $e');
      // Revert on error
      state = state.copyWith(isGhostModeEnabled: !enabled);
    }
  }

  Future<void> retryLocation() async {
    state = state.copyWith(isLoading: true, error: null);
    await _initLocation();
  }

  void setDogFilters({
    List<DogSize>? sizes,
    List<DogGender>? genders,
    List<String>? breeds,
  }) {
    state = state.copyWith(
      filterDogSizes: sizes,
      filterDogGenders: genders,
      filterDogBreeds: breeds,
    );
     _updateMarkers();
  }

  void clearDogFilters() {
     state = state.copyWith(
       filterDogSizes: [],
       filterDogGenders: [],
       filterDogBreeds: [],
     );
     _updateMarkers();
  }

  void _updateMarkers() async {
    final List<Marker> markers = [];
    final query = state.searchQuery.toLowerCase();
    final Map<String, List<DogModel>> pendingCacheUpdates = {};

    // 1. User Markers
    for (final userLoc in _currentUserLocations) {
      // Skip if blocked
      if (state.blockedUsers.contains(userLoc.uid)) continue;

      final currentUser = _ref.read(authServiceProvider).currentUser;
      if (currentUser?.uid == userLoc.uid) continue;

      try {
        // Use cached profile or fetch
        UserModel? userProfile = _userCache[userLoc.uid];
        if (userProfile == null) {
          userProfile = await _userService.getUserById(userLoc.uid);
          if (userProfile != null) {
            _userCache[userLoc.uid] = userProfile;
          }
        }

        if (userProfile != null) {
          // 0. Ghost Mode Check (Hide invisible users)
          if (userProfile.isGhost) continue;

          // Privacy Check
          bool isVisible = false;
          final currentUserId = currentUser!.uid;

          switch (userProfile.locationPrivacy) {
            case LocationPrivacy.everyone:
              isVisible = true;
              break;
            case LocationPrivacy.friends:
              isVisible = userProfile.friends.contains(currentUserId);
              break;
            case LocationPrivacy.closeFriends:
              isVisible = userProfile.closeFriends.contains(currentUserId);
              break;
            case LocationPrivacy.custom:
              isVisible = userProfile.locationWhitelist.contains(currentUserId);
              break;
          }

          if (!isVisible) continue;

          // Filter by name
          if (query.isNotEmpty && !userProfile.fullName.toLowerCase().contains(query)) {
            continue;
          }
          
          // --- PET FILTERS (Global & Premium) ---
          final hasPremiumDogFilters = state.filterDogSizes.isNotEmpty || 
                                       state.filterDogGenders.isNotEmpty ||
                                       state.filterDogBreeds.isNotEmpty;

          final hasSpeciesFilter = state.filterPetSpecies != null;
          final hasDogFilters = hasPremiumDogFilters || hasSpeciesFilter;

          if (hasDogFilters) {
             List<DogModel>? userDogs = state.dogCache[userLoc.uid];
             bool dogsFetchedNow = false;
             
             if (userDogs == null) {
                try {
                  userDogs = await _dogService.getDogsByOwnerId(userLoc.uid);
                  dogsFetchedNow = true;
                } catch (e) {
                   print('Error fetching dogs: $e');
                   userDogs = [];
                }
             }
             
             // 0. Empty check: If filtering by pets, user must HAVE pets.
             if (userDogs == null || userDogs.isEmpty) continue;

             if (dogsFetchedNow) {
                pendingCacheUpdates[userLoc.uid] = userDogs;
             }

             // 1. Check Species Filter (Global)
             if (hasSpeciesFilter) {
               final hasSpecies = userDogs.any((pet) => pet.species == state.filterPetSpecies);
               if (!hasSpecies) continue;
             }

             // 2. Check Premium Filters (Dog Specific)
             if (hasPremiumDogFilters) {
                 bool isMatch(DogModel dog) {
                    if (state.filterDogSizes.isNotEmpty && !state.filterDogSizes.contains(dog.size)) return false;
                    if (state.filterDogGenders.isNotEmpty && !state.filterDogGenders.contains(dog.gender)) return false;
                    
                    if (state.filterDogBreeds.isNotEmpty) {
                       bool breedMatch = false;
                       for (final filter in state.filterDogBreeds) {
                          if (dog.breed.toLowerCase().contains(filter.toLowerCase())) {
                            breedMatch = true;
                            break;
                          }
                       }
                       if (!breedMatch) return false;
                    }
                    return true;
                 }
                 
                 if (!userDogs.any(isMatch)) continue;
             }
          }

          markers.add(
            Marker(
              point: LatLng(userLoc.latitude, userLoc.longitude),
              width: 40,
              height: 40,
              child: GestureDetector(
                onTap: () {
                   state = state.copyWith(selectedUser: userProfile);
                },
                child: _buildUserMarker(userProfile),
              ),
            ),
          );
        }
      } catch (e) {
        print('Error processing user ${userLoc.uid}: $e');
      }
    }

    // 2. Walk Markers
    for (final walk in state.allWalks) {
      if (state.blockedUsers.contains(walk.creatorId)) continue;
      
      // Search Filter
      if (query.isNotEmpty) {
        final matches = (walk.title.toLowerCase().contains(query) ?? false) ||
                        (walk.description.toLowerCase().contains(query) ?? false);
        if (!matches) continue;
      }

      markers.add(
        Marker(
          point: LatLng(walk.meetingPoint.latitude, walk.meetingPoint.longitude),
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () {
              state = state.copyWith(selectedWalk: walk);
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.directions_walk, color: Colors.white, size: 24),
            ),
          ),
        ),
      );
    }

    // 3. Announcement Markers
    for (final announcement in state.allAnnouncements) {
      if (state.blockedUsers.contains(announcement.userId)) continue;

      // Search Filter
      if (query.isNotEmpty) {
        final matches = announcement.message.toLowerCase().contains(query) ||
                        announcement.authorName.toLowerCase().contains(query);
        if (!matches) continue;
      }

      markers.add(
        Marker(
          point: LatLng(announcement.location.latitude, announcement.location.longitude),
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () {
               state = state.copyWith(selectedAnnouncement: announcement);
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.campaign, color: Colors.white, size: 24),
            ),
          ),
        ),
      );
    }

    // 4. Safety Alert Markers
    for (final alert in state.allAlerts) {
       // Search Filter (Type displayName matches?)
       if (query.isNotEmpty) {
         final matches = alert.type.displayName.toLowerCase().contains(query) ||
                         (alert.description?.toLowerCase().contains(query) ?? false);
         if (!matches) continue;
       }

      markers.add(
        Marker(
          point: LatLng(alert.latitude, alert.longitude),
          width: 45,
          height: 45,
          child: GestureDetector(
            onTap: () {
              state = state.copyWith(selectedAlert: alert);
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
            ),
          ),
        ),
      );
    }
    
    // 5. SOS Markers (Priority - Added)
    for (final sos in state.allSOSAlerts) {
      // Search Filter
      if (query.isNotEmpty) {
         // Maybe search by "sos" or description
         final matches = (sos.message?.toLowerCase().contains(query) ?? false) ||
                         query == 'sos';
         if (!matches) continue;
      }

      markers.add(
        Marker(
          point: LatLng(sos.latitude, sos.longitude),
          width: 60,
          height: 60,
          child: GestureDetector(
            onTap: () {
              state = state.copyWith(selectedSOS: sos);
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                // "Pulse" effect ring (static for now)
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                     color: Colors.red.withOpacity(0.3),
                     shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.sos, color: Colors.white, size: 30),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // 6. Event Markers (Added)
    for (final event in state.allEvents) {
      if (state.blockedUsers.contains(event.creatorId)) continue;

      // Search Filter
      if (query.isNotEmpty) {
        final matches = (event.title.toLowerCase().contains(query) ?? false) ||
                        (event.description.toLowerCase().contains(query) ?? false);
        if (!matches) continue;
      }
      
      markers.add(
        Marker(
          point: LatLng(event.latitude, event.longitude),
          width: 45,
          height: 45,
          child: GestureDetector(
            onTap: () {
              state = state.copyWith(selectedEvent: event);
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.event_available, color: Colors.white, size: 26),
            ),
          ),
        ),
      );
    }



    if (mounted) {
       final finalCache = Map<String, List<DogModel>>.from(state.dogCache);
       if (pendingCacheUpdates.isNotEmpty) {
          finalCache.addAll(pendingCacheUpdates);
       }
       state = state.copyWith(markers: markers, dogCache: finalCache);
    }
  }

  void _startListeningToNearbyUsers(Position center) {
    // Cancel existing subscription if any
    _nearbyUsersSubscription?.cancel();

    _nearbyUsersSubscription = _mapService
        .getNearbyUsers(
      latitude: center.latitude,
      longitude: center.longitude,
      radiusInKm: 5.0, // 5km radius
    )
        .listen(
      (userLocations) {
        _currentUserLocations = userLocations;
        _updateMarkers();
      },
      onError: (e) {
        print('Error fetching nearby users: $e');
      },
    );
  }

  void clearSelectedUser() {
    state = state.copyWith(selectedUser: null);
  }

  void clearSelectedWalk() {
    state = state.copyWith(selectedWalk: null);
  }

  void clearSelectedAnnouncement() {
    state = state.copyWith(selectedAnnouncement: null);
  }

  void clearSelectedAlert() {
    state = state.copyWith(selectedAlert: null);
  }
  
  void clearSelectedSOS() { // Added
    state = state.copyWith(selectedSOS: null);
  }

  void clearSelectedEvent() { // Added
    state = state.copyWith(selectedEvent: null);
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _nearbyUsersSubscription?.cancel();
    _walksSubscription?.cancel();
    _announcementsSubscription?.cancel();
    _alertsSubscription?.cancel();
    _sosSubscription?.cancel(); // Added
    _eventsSubscription?.cancel(); // Added
    super.dispose();
  }
  Future<bool> _tryFallbackToUserAddress() async {
    try {
      final firebaseUser = _ref.read(authServiceProvider).currentUser;
      if (firebaseUser != null) {
        final userModel = _ref.read(currentUserProfileProvider).value;
        if (userModel != null) {
          double? lat = userModel.homeLatitude;
          double? lng = userModel.homeLongitude;

          // If coordinates are missing, try geocoding with better accuracy
          if (lat == null || lng == null) {
            if (userModel.address != null && userModel.address!.isNotEmpty) {
              print('Attempting to geocode address: ${userModel.address}, Italia');
              final locations = await locationFromAddress('${userModel.address!}, Italia');
              if (locations.isNotEmpty) {
                lat = locations.first.latitude;
                lng = locations.first.longitude;
              }
            }
          }

          if (lat != null && lng != null) {
            final position = Position(
              latitude: lat,
              longitude: lng,
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              heading: 0,
              speed: 0,
              speedAccuracy: 0,
              altitudeAccuracy: 0, 
              headingAccuracy: 0,
              floor: null,
              isMocked: true,
            );
            _updatePosition(position);
            return true;
          }
        }
      }
    } catch (e) {
      print('Address fallback failed: $e');
    }
    return false;
  }

  Widget _buildUserMarker(UserModel user) {
      if (user.accountType == AccountType.business) {
          return Container(
             padding: const EdgeInsets.all(4),
             decoration: BoxDecoration(
               color: Colors.amber, 
               shape: BoxShape.circle,
               border: Border.all(color: Colors.white, width: 2),
               boxShadow: [
                 BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 5, offset: const Offset(0, 3))
               ]
             ),
             child: const Icon(Icons.store, color: Colors.white, size: 20),
          );
      }
      
      return Container(
        decoration: BoxDecoration(
           color: Colors.white,
           shape: BoxShape.circle,
           border: Border.all(color: Colors.deepPurple, width: 2), 
           boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))
           ]
        ),
        child: ClipOval(
           child: user.photoUrl != null 
              ? Image.network(user.photoUrl!, fit: BoxFit.cover)
              : const Icon(Icons.person, color: Colors.deepPurple),
        ),
      );
  }
}

/// Map Controller Provider
final mapControllerProvider =
    StateNotifierProvider<MapStateController, MapState>((ref) {
  return MapStateController(
    ref.watch(locationServiceProvider),
    ref.watch(mapServiceProvider),
    ref.watch(userServiceProvider),
    ref,
  );
});

