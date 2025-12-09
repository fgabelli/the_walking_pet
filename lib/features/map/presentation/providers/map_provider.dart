import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/map_service.dart';
import '../../../../core/services/user_service.dart';
import '../../../../core/services/walk_service.dart';
import '../../../../shared/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../walks/presentation/providers/walk_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../../shared/models/walk_model.dart';
import '../../../../shared/models/announcement_model.dart';
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

  MapStateController(
    this._locationService,
    this._mapService,
    this._userService,
    this._ref,
  ) : super(MapState()) {
    _initLocation();
    _startListeningToWalks();
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

      // Get initial position
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        print('Initial position found: ${position.latitude}, ${position.longitude}');
        _updatePosition(position);
      } else {
        print('Initial position is null');
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

  void _updateMarkers() async {
    final List<Marker> markers = [];
    final query = state.searchQuery.toLowerCase();

    // 1. User Markers
    for (final userLoc in _currentUserLocations) {
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

          markers.add(
            Marker(
              point: LatLng(userLoc.latitude, userLoc.longitude),
              width: 40,
              height: 40,
              child: GestureDetector(
                onTap: () {
                   state = state.copyWith(selectedUser: userProfile);
                },
                child: Container(
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
      // Filter by query if needed (e.g. walk title or description if added later)
      // For now, we can filter by location or just show all
      
      markers.add(
        Marker(
          point: LatLng(walk.meetingPoint.latitude, walk.meetingPoint.longitude),
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () {
              // Handle walk tap
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
      markers.add(
        Marker(
          point: LatLng(announcement.location.latitude, announcement.location.longitude),
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () {
              // Handle announcement tap
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

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _nearbyUsersSubscription?.cancel();
    _walksSubscription?.cancel();
    _announcementsSubscription?.cancel();
    super.dispose();
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

