import 'dart:async'; // Keep this
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/map_service.dart';
import '../../../../core/services/user_service.dart';
import '../../../../core/services/walk_service.dart';
import '../../../../core/services/safety_service.dart'; // Added
import '../../../../shared/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../walks/presentation/providers/walk_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../../shared/models/walk_model.dart';
import '../../../../shared/models/announcement_model.dart';
import '../../../../shared/models/safety_alert_model.dart'; // Added
import '../../../nextdoor/data/nextdoor_service.dart';
import '../../../nextdoor/presentation/providers/nextdoor_provider.dart';

/// Location Service Provider
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// Map Service Provider
final mapServiceProvider = Provider<MapService>((ref) {
  return MapService();
});

/// Map State
class MapState {
  final Position? currentPosition;
  final List<Marker> markers;
  final bool isLoading;
  final String? error;
  final bool isLocationEnabled;
  final UserModel? selectedUser;
  final String searchQuery;
  final List<UserLocation> allUserLocations;
  final List<WalkModel> allWalks;
  final List<AnnouncementModel> allAnnouncements;
  final List<SafetyAlertModel> allAlerts; // Added
  final WalkModel? selectedWalk;
  final AnnouncementModel? selectedAnnouncement;
  final SafetyAlertModel? selectedAlert; // Added
  final List<String> blockedUsers;
  // Filters
  final String? filterBreed;
  final Gender? filterGender;
  final bool isGhostModeEnabled; // Local user setting state

  MapState({
    this.currentPosition,
    this.markers = const [],
    this.isLoading = true,
    this.error,
    this.isLocationEnabled = false,
    this.selectedUser,
    this.searchQuery = '',
    this.allUserLocations = const [],
    this.allWalks = const [],
    this.allAnnouncements = const [],
    this.allAlerts = const [], // Added
    this.selectedWalk,
    this.selectedAnnouncement,
    this.selectedAlert, // Added
    this.blockedUsers = const [],
    this.filterBreed,
    this.filterGender,
    this.isGhostModeEnabled = false,
  });

  MapState copyWith({
    Position? currentPosition,
    List<Marker>? markers,
    bool? isLoading,
    String? error,
    bool? isLocationEnabled,
    UserModel? selectedUser,
    String? searchQuery,
    List<UserLocation>? allUserLocations,
    List<WalkModel>? allWalks,
    List<AnnouncementModel>? allAnnouncements,
    List<SafetyAlertModel>? allAlerts, // Added
    WalkModel? selectedWalk,
    AnnouncementModel? selectedAnnouncement,
    SafetyAlertModel? selectedAlert, // Added
    List<String>? blockedUsers,
    String? filterBreed,
    Gender? filterGender,
    bool? isGhostModeEnabled,
  }) {
    return MapState(
      currentPosition: currentPosition ?? this.currentPosition,
      markers: markers ?? this.markers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isLocationEnabled: isLocationEnabled ?? this.isLocationEnabled,
      selectedUser: selectedUser,
      searchQuery: searchQuery ?? this.searchQuery,
      allUserLocations: allUserLocations ?? this.allUserLocations,
      allWalks: allWalks ?? this.allWalks,
      allAnnouncements: allAnnouncements ?? this.allAnnouncements,
      allAlerts: allAlerts ?? this.allAlerts, // Added
      selectedWalk: selectedWalk, // No null coalescing to allow clearing
      selectedAnnouncement: selectedAnnouncement, // No null coalescing to allow clearing
      selectedAlert: selectedAlert, // No null coalescing
      blockedUsers: blockedUsers ?? this.blockedUsers,
      filterBreed: filterBreed ?? this.filterBreed,
      filterGender: filterGender ?? this.filterGender,
      isGhostModeEnabled: isGhostModeEnabled ?? this.isGhostModeEnabled,
    );
  }
}

/// Map Controller
class MapStateController extends StateNotifier<MapState> {
  final LocationService _locationService;
  final MapService _mapService;
  final UserService _userService;
  final Ref _ref;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<List<UserLocation>>? _nearbyUsersSubscription;
  StreamSubscription<List<WalkModel>>? _walksSubscription;
  StreamSubscription<List<AnnouncementModel>>? _announcementsSubscription;
  StreamSubscription<List<SafetyAlertModel>>? _alertsSubscription; // Added

  MapStateController(
    this._locationService,
    this._mapService,
    this._userService,
    this._ref,
  ) : super(MapState()) {
    _initLocation();
    _startListeningToWalks();
    _startListeningToProfile();
    _startListeningToAlerts(); // Added
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

  // Listen to alerts (Moved active logic to service query)
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
        print('Permission denied, trying fallback to user address');
        final fallbackSuccess = await _tryFallbackToUserAddress();
        
        if (!fallbackSuccess) {
          state = state.copyWith(
            isLoading: false,
            isLocationEnabled: false,
            error: 'Permessi di localizzazione negati',
          );
        }
        return;
      }

      state = state.copyWith(isLocationEnabled: true);

      // Get initial position with timeout
      try {
        final position = await _locationService.getCurrentPosition().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('Initial position fetch timed out, trying fallback');
            return null;
          },
        );

        if (position != null) {
          print('Initial position found: ${position.latitude}, ${position.longitude}');
          _updatePosition(position);
        } else {
          print('Initial position is null/timed out, trying fallback to user address');
          // Wait for fallback
           final fallbackSuccess = await _tryFallbackToUserAddress();
           if (!fallbackSuccess) {
             // If fallback also fails, we must stop loading to show "Rome" or map structure at least
             // The map widget usually handles null center by default or we set a default
             // But we need to turn off isLoading
              state = state.copyWith(isLoading: false, error: 'Impossibile recuperare la posizione. Mappa centrata su Roma.');
           }
        }
      } catch (e) {
         print('Error in initial position fetch: $e');
         await _tryFallbackToUserAddress();
         state = state.copyWith(isLoading: false); // Ensure loading is off
      }

      // Start listening to position updates
      _positionSubscription = _locationService.getPositionStream().listen(
        (position) {
          print('Position update: ${position.latitude}, ${position.longitude}');
          _updatePosition(position);
        },
        onError: (e) {
          print('Position stream error: $e');
          state = state.copyWith(error: e.toString());
        },
      );
    } catch (e) {
      print('Error initializing location: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _updatePosition(Position position) {
    state = state.copyWith(
      currentPosition: position,
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

  void _updateMarkers() async {
    final List<Marker> markers = [];
    final query = state.searchQuery.toLowerCase();

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
            case LocationPrivacy.custom:
              isVisible = userProfile.locationWhitelist.contains(currentUserId);
              break;
          }

          if (!isVisible) continue;

          // Filter by name
          if (query.isNotEmpty && !userProfile.fullName.toLowerCase().contains(query)) {
            continue;
          }
          
          // Premium Filters (Gender)
          if (state.filterGender != null && userProfile.gender != state.filterGender) {
            continue;
          }
          
          // Premium Filters (Breed - requires fetching dogs)
          // Since dogs are not in UserModel yet, we might need to fetch them or rely on simple user filters for now.
          // For MVP, if filterBreed is set, we'd need to check the user's dogs.
          // This would require fetching dogs for EVERY user which is heavy. 
          // Suggestion: Filter primarily by what's in UserModel or accepting that Breed filter is expensive.
          // Or, just skip for now and do Gender only for MVP speed.
          // Let's implement logic but maybe comment out breed fetching loop if too complex.
          
          markers.add(
            Marker(
              point: LatLng(userLoc.latitude, userLoc.longitude),
              width: 40,
              height: 40,
              child: GestureDetector(
                onTap: () {
                   state = state.copyWith(selectedUser: userProfile);
                },
                child: userProfile!.accountType == AccountType.business
                    ? Container(
                        decoration: BoxDecoration(
                          color: Colors.amber, // Business Gold
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.store, color: Colors.white, size: 24),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.deepPurple, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: userProfile.photoUrl != null
                              ? Image.network(
                                  userProfile.photoUrl!,
                                  fit: BoxFit.cover,
                                )
                              : const Icon(Icons.person, color: Colors.deepPurple),
                        ),
                      ),
              ),
            ),
          );
        }
      } catch (e) {
        print('Error fetching user profile for map: $e');
      }
    }

    // 2. Walk Markers
    for (final walk in state.allWalks) {
      // Skip if creator is blocked
      if (state.blockedUsers.contains(walk.creatorId)) continue;

      // Filter by query if needed (e.g. walk title or description if added later)
      // For now, we can filter by location or just show all
      
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
      // Skip if author is blocked
      if (state.blockedUsers.contains(announcement.userId)) continue;

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

    // 4. Safety Alert Markers (Added)
    for (final alert in state.allAlerts) {
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

    state = state.copyWith(markers: markers);
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

  void clearSelectedAlert() { // Added
    state = state.copyWith(selectedAlert: null);
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _nearbyUsersSubscription?.cancel();
    _walksSubscription?.cancel();
    _announcementsSubscription?.cancel();
    _alertsSubscription?.cancel(); // Added
    super.dispose();
  }
  Future<bool> _tryFallbackToUserAddress() async {
    try {
      final firebaseUser = _ref.read(authServiceProvider).currentUser;
      if (firebaseUser != null) {
        final userModel = await _userService.getUserById(firebaseUser.uid);
        
        if (userModel != null && userModel.address != null && userModel.address!.isNotEmpty) {
          print('Attempting to geocode address: ${userModel.address}');
          final locations = await locationFromAddress(userModel.address!);
          if (locations.isNotEmpty) {
            final loc = locations.first;
            final position = Position(
              latitude: loc.latitude,
              longitude: loc.longitude,
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

