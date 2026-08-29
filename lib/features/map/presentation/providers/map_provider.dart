import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';

import '../../../../shared/constants/map_markers.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/map_service.dart';
import '../../../../core/services/user_service.dart';
import '../../../../core/services/sos_service.dart';
import '../../../../core/services/event_service.dart';
import '../../../../core/services/pet_business_service.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/models/event_model.dart';
import '../../../../shared/models/pet_business_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../walks/presentation/providers/walk_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../../shared/models/walk_model.dart';
import '../../../../shared/models/announcement_model.dart';
import '../../../../shared/models/safety_alert_model.dart';
import '../../../../shared/models/lost_pet_alert_model.dart';
import '../../../../shared/models/lost_pet_sighting_model.dart';
import '../../../nextdoor/presentation/providers/nextdoor_provider.dart';
import '../../../../shared/models/dog_model.dart';
import '../../../../core/services/dog_service.dart';
import '../../../profile/presentation/providers/dog_provider.dart';
import '../../../../core/services/notification_service.dart';


/// Location Service Provider
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// Map Service Provider
final mapServiceProvider = Provider<MapService>((ref) {
  return MapService();
});

/// Proximity Alert Model (for in-app banner)
class ProximityAlert {
  final String id;
  final String title;
  final String message;
  final String type; // 'safety' or 'sos'
  final double distanceMeters;

  const ProximityAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.distanceMeters,
  });
}

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
  final List<LostPetSightingModel> allSightings; // Added
  final List<EventModel> allEvents; // Added
  final WalkModel? selectedWalk;
  final AnnouncementModel? selectedAnnouncement;
  final SafetyAlertModel? selectedAlert;
  final LostPetAlertModel? selectedSOS; // Added
  final LostPetSightingModel? selectedSighting; // Added
  final EventModel? selectedEvent; // Added
  final List<String> blockedUsers;
  // Filters
  // User Filters
  final String? filterBreed; // Legacy/User-based? Or reuse for Dog Breed? Let's use specific ones.
  final Gender? filterGender; // User Gender
  final List<PetSpecies> filterPetSpecies; // Added: Global Species Filter (Free)
  
  // Dog Compatibility Filters (Premium)
  final Map<String, List<DogModel>> dogCache; // ownerId -> List<DogModel>
  final List<DogSize> filterDogSizes;
  final List<DogGender> filterDogGenders;
  final List<String> filterDogBreeds;
  final bool? filterIsSterilized;

  final bool isGhostModeEnabled; // Local user setting state
  final bool isSharingActive; // Manual Check-in State (Session)
  
  // Radar Logic (Discovery of Invisible Users)
  final int radarMatchCount;
  final List<String> radarMatchIds; 
  
  // Radius Configuration
  final double radiusInKm;

  // Pet Businesses
  final List<PetBusinessModel> allPetBusinesses;
  final PetBusinessModel? selectedPetBusiness;
  final bool showPetBusinesses; // Toggle visibility of pet business markers
  final List<PetBusinessCategory> filterBusinessCategories; // Empty = show all

  // Proximity Alert (shown as banner when user approaches danger)
  final ProximityAlert? proximityAlert;

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
    this.allSightings = const [], // Added
    this.allEvents = const [],
    this.selectedWalk,
    this.selectedAnnouncement,
    this.selectedAlert,
    this.selectedSOS,
    this.selectedSighting, // Added
    this.selectedEvent,
    this.blockedUsers = const [],
    this.filterBreed,
    this.filterGender,
    this.filterPetSpecies = const [], // Changed to list default empty
    this.dogCache = const {},
    this.filterDogSizes = const [],
    this.filterDogGenders = const [],
    this.filterDogBreeds = const [],
    this.filterIsSterilized,
    this.isGhostModeEnabled = false,
    this.isSharingActive = false, // Default false (Manual Check-in required)
    this.radarMatchCount = 0,
    this.radarMatchIds = const [],
    this.radiusInKm = 10.0,
    this.allPetBusinesses = const [],
    this.selectedPetBusiness,
    this.showPetBusinesses = true, // Show by default - loaded once on map init
    this.filterBusinessCategories = const [],
    this.proximityAlert,
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
    List<LostPetSightingModel>? allSightings, // Added
    List<EventModel>? allEvents,
    WalkModel? selectedWalk,
    AnnouncementModel? selectedAnnouncement,
    SafetyAlertModel? selectedAlert,
    LostPetAlertModel? selectedSOS,
    LostPetSightingModel? selectedSighting, // Added
    EventModel? selectedEvent,
    List<String>? blockedUsers,
    String? filterBreed,
    Gender? filterGender,
    List<PetSpecies>? filterPetSpecies, // Changed to List
    Map<String, List<DogModel>>? dogCache,
    List<DogSize>? filterDogSizes,
    List<DogGender>? filterDogGenders,
    List<String>? filterDogBreeds,
    bool? filterIsSterilized,
    bool? isGhostModeEnabled,
    bool? isSharingActive,
    int? radarMatchCount,
    List<String>? radarMatchIds,
    double? radiusInKm,
    List<PetBusinessModel>? allPetBusinesses,
    PetBusinessModel? selectedPetBusiness,
    bool? showPetBusinesses,
    List<PetBusinessCategory>? filterBusinessCategories,
    ProximityAlert? proximityAlert,
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
      allSightings: allSightings ?? this.allSightings, // Added
      allEvents: allEvents ?? this.allEvents,
      selectedWalk: selectedWalk,
      selectedAnnouncement: selectedAnnouncement,
      selectedAlert: selectedAlert,
      selectedSOS: selectedSOS,
      selectedSighting: selectedSighting, // Added
      selectedEvent: selectedEvent,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      filterBreed: filterBreed ?? this.filterBreed,
      filterGender: filterGender ?? this.filterGender,
      filterPetSpecies: filterPetSpecies ?? this.filterPetSpecies, // Changed
      dogCache: dogCache ?? this.dogCache,
      filterDogSizes: filterDogSizes ?? this.filterDogSizes,
      filterDogGenders: filterDogGenders ?? this.filterDogGenders,
      filterDogBreeds: filterDogBreeds ?? this.filterDogBreeds,
      filterIsSterilized: filterIsSterilized ?? this.filterIsSterilized,
      isGhostModeEnabled: isGhostModeEnabled ?? this.isGhostModeEnabled,
      isSharingActive: isSharingActive ?? this.isSharingActive,
      radarMatchCount: radarMatchCount ?? this.radarMatchCount,
      radarMatchIds: radarMatchIds ?? this.radarMatchIds,
      radiusInKm: radiusInKm ?? this.radiusInKm,
      allPetBusinesses: allPetBusinesses ?? this.allPetBusinesses,
      selectedPetBusiness: selectedPetBusiness,
      showPetBusinesses: showPetBusinesses ?? this.showPetBusinesses,
      filterBusinessCategories: filterBusinessCategories ?? this.filterBusinessCategories,
      proximityAlert: proximityAlert,
    );
  }
}

/// Map Controller
class MapStateController extends StateNotifier<MapState> {
  final LocationService _locationService;
  final MapService _mapService;
  final UserService _userService;
  final DogService _dogService;
  final PetBusinessService _petBusinessService;
  final Ref _ref;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<List<UserLocation>>? _nearbyUsersSubscription;
  StreamSubscription<List<WalkModel>>? _walksSubscription;
  StreamSubscription<List<AnnouncementModel>>? _announcementsSubscription;
  StreamSubscription<List<SafetyAlertModel>>? _alertsSubscription;
  StreamSubscription<List<LostPetAlertModel>>? _sosSubscription;
  StreamSubscription<List<LostPetSightingModel>>? _sightingsSubscription; // Added
  StreamSubscription<List<EventModel>>? _eventsSubscription;
  
  // MANUAL CHECK-IN STATE (Apple Guideline 5.1.2)
  // Default to FALSE to ensure no automatic check-in.
  bool _isSharingLocation = false;
  
  // Race condition guard for _updateMarkers() — prevents stale async executions
  // from overwriting fresher data
  int _markersVersion = 0;
  Timer? _markersDebounce;
  
  // Track which alerts we already warned about (avoid repeating)
  final Set<String> _notifiedAlertIds = {};

  MapStateController(
    this._locationService,
    this._mapService,
    this._userService,
    this._dogService,
    this._petBusinessService,
    this._ref,
  ) : super(MapState()) {
    _startListeningToWalks();
    _startListeningToProfile();
    _startListeningToAlerts();
    _startListeningToSOS();
    _startListeningToEvents();
    _startListeningToSightings(); // Added
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
          _startListeningToSightings(); // Added
        }
      });
    });
  }

  void _startListeningToSightings() {
    final user = _ref.read(authServiceProvider).currentUser;
    if (user != null) {
      _sightingsSubscription?.cancel();
      _sightingsSubscription = _ref.read(sosServiceProvider).getSightingsForOwnerStream(user.uid).listen(
        (sightings) {
          state = state.copyWith(allSightings: sightings);
          _updateMarkers();
        },
        onError: (e) {
          print('Error fetching sightings: $e');
        },
      );
    } else {
      _sightingsSubscription?.cancel();
      _sightingsSubscription = null;
      state = state.copyWith(allSightings: const []);
    }
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
      radiusInKm: state.radiusInKm,
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

  Future<void> initLocation() async {
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

      // 3. Try Last Known Position (Fastest) to show something immediately
      final lastKnown = await _locationService.getLastKnownPosition();
      if (lastKnown != null) {
        print('Using Last Known Position: ${lastKnown.latitude}, ${lastKnown.longitude}');
        _updatePosition(lastKnown);
      } else {
        // IMPROVED: If no last known, apply fallback IMMEDIATELY so map renders.
        // Don't wait 30s while staring at a white screen.
        print('No last known position. Applying fallback immediately while searching...');
        await _applyFallbackPosition();
      }

      // 4. Start Listening (Best for updates)
      _positionSubscription = _locationService.getPositionStream().listen(
        (position) {
          print('Position update: ${position.latitude}, ${position.longitude}');
          _updatePosition(position);
        },
        onError: (e) {
          print('Position stream error: $e');
        },
      );

      // 5. Urge a fresh fix (Background)
      // We do this even if we applied fallback, to try and get real GPS.
      // We don't await this to avoid blocking UI.
      if (lastKnown == null) {
         _locationService.getCurrentPosition().then((position) {
            print('Fresh GPS fix obtained!');
            _updatePosition(position);
         }).catchError((e) {
            print('Fresh GPS fix failed: $e');
            // We already have fallback, so no need to show error causing white screen.
            // Maybe show a snackbar? For now silent is better than broken UI.
         });
      }
      
    } catch (e) {
      print('Error initializing location: $e');
      // If we completely failed (e.g. permission error before fallback), we might need to show it.
      // If we have no position yet, show error.
      if (state.currentPosition == null) {
         state = state.copyWith(isLoading: false, error: 'Errore GPS: $e');
      }
    }
  }

  Future<void> _applyFallbackPosition() async {
    double fallbackLat = 41.9028; // Rome
    double fallbackLng = 12.4964;

    try {
      final firebaseUser = _ref.read(authServiceProvider).currentUser;
      if (firebaseUser != null) {
          final userProfile = await _userService.getUserById(firebaseUser.uid);
          if (userProfile != null && userProfile.homeLatitude != null && userProfile.homeLongitude != null) {
            print('Using User Home Location as fallback');
            fallbackLat = userProfile.homeLatitude!;
            fallbackLng = userProfile.homeLongitude!;
          }
      }
    } catch (e) {
      print('Error fetching user home for fallback: $e');
    }

    final fallbackPosition = Position(
      latitude: fallbackLat,
      longitude: fallbackLng,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0, 
      headingAccuracy: 0,
      isMocked: true, 
    );
    
    _updatePosition(fallbackPosition);
    
    // Explicitly ensure loading is off and error is clear
    state = state.copyWith(
      isLoading: false, 
      error: null, // Clear any previous error since we have a position now
    );
  }

  void _updatePosition(Position position) {
    state = state.copyWith(
      currentPosition: position,
      isMocked: position.isMocked,
      isLoading: false,
    );

    // Load pet businesses ONCE on first position (not on every update)
    // The 6h cache + 2-decimal key precision handles the rest
    if (state.allPetBusinesses.isEmpty) {
      _loadNearbyPetBusinesses(position);
    }

    // Always load nearby announcements (read-only, public data)
    if (_announcementsSubscription == null) {
      _startListeningToAnnouncements(position);
    }

    // Check proximity to active alerts (works even without check-in)
    _checkProximityAlerts(position);

    // Update user location in Firestore ONLY IF sharing is active (Manual Check-In)
    if (_isSharingLocation) {
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
      }
    }
  }

  // ── PROXIMITY ALERT SYSTEM ─────────────────────────────
  // Checks if the user is within 500m of any active safety alert or SOS.
  // Shows a warning banner and local notification when approaching danger.
  static const double _proximityThresholdKm = 0.5; // 500 meters, walking distance

  void _checkProximityAlerts(Position userPos) {
    ProximityAlert? closestAlert;
    double closestDistance = double.infinity;

    // Check safety alerts
    for (final alert in state.allAlerts) {
      final dist = _haversineDistance(
        userPos.latitude, userPos.longitude,
        alert.latitude, alert.longitude,
      );
      if (dist <= _proximityThresholdKm && dist < closestDistance) {
        if (_notifiedAlertIds.contains('safety_${alert.id}')) continue;
        closestDistance = dist;
        String typeLabel;
        switch (alert.type) {
          case SafetyAlertType.poison:
            typeLabel = '☠️ Bocconi avvelenati';
            break;
          case SafetyAlertType.glass:
            typeLabel = '⚠️ Vetri/Pericoli';
            break;
          case SafetyAlertType.aggression:
            typeLabel = '🐕 Cane aggressivo';
            break;
          case SafetyAlertType.police:
            typeLabel = '👮 Controllo';
            break;
          default:
            typeLabel = '⚠️ Pericolo';
        }
        closestAlert = ProximityAlert(
          id: 'safety_${alert.id}',
          title: typeLabel,
          message: alert.description ?? 'Pericolo segnalato a ${(dist * 1000).round()}m da te!',
          type: 'safety',
          distanceMeters: dist * 1000,
        );
      }
    }

    // Check SOS alerts
    for (final sos in state.allSOSAlerts) {
      final dist = _haversineDistance(
        userPos.latitude, userPos.longitude,
        sos.latitude, sos.longitude,
      );
      if (dist <= _proximityThresholdKm && dist < closestDistance) {
        if (_notifiedAlertIds.contains('sos_${sos.id}')) continue;
        closestDistance = dist;
        closestAlert = ProximityAlert(
          id: 'sos_${sos.id}',
          title: '🆘 Pet smarrito nelle vicinanze',
          message: sos.message ?? 'Un animale si è perso a ${(dist * 1000).round()}m da te!',
          type: 'sos',
          distanceMeters: dist * 1000,
        );
      }
    }

    if (closestAlert != null) {
      _notifiedAlertIds.add(closestAlert.id);
      state = state.copyWith(proximityAlert: closestAlert);

      // Fire a local notification with sound so user is alerted
      // even if not actively looking at the map
      try {
        _ref.read(notificationServiceProvider).showProximityAlert(
          title: closestAlert.title,
          body: closestAlert.message,
          alertId: closestAlert.id,
        );
      } catch (e) {
        print('Error showing proximity notification: $e');
      }
    }
  }

  /// Dismiss the current proximity alert banner
  void dismissProximityAlert() {
    state = state.copyWith(proximityAlert: null);
  }

  /// Haversine distance between two GPS coordinates (in km)
  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // Earth's radius in km
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  void setSearchRadius(double radiusInKm) {
    state = state.copyWith(radiusInKm: radiusInKm);
    // Restart listeners with new radius
    if (state.currentPosition != null) {
       _startListeningToNearbyUsers(state.currentPosition!);
       _startListeningToAnnouncements(state.currentPosition!);
    }
  }

  void _startListeningToNearbyUsers(Position center) {
    _nearbyUsersSubscription?.cancel();
    _nearbyUsersSubscription = _mapService.getNearbyUsers(
      latitude: center.latitude,
      longitude: center.longitude,
      radiusInKm: state.radiusInKm,
    ).listen(
      (userLocations) {
        _currentUserLocations = userLocations;
        _updateMarkers();
      },
      onError: (e) {
        print('Error fetching nearby users: $e');
      },
    );
  }

  // MANUAL CHECK-IN TOGGLE
  Future<void> toggleLocationSharing(bool enable) async {
    _isSharingLocation = enable;
    // Force update immediately if enabled
    if (enable && state.currentPosition != null) {
       _updatePosition(state.currentPosition!);
    } else if (!enable) {
       // Go Offline
       final user = _ref.read(authServiceProvider).currentUser;
       if (user != null) {
         // Optionally delete location or set offline
         // For now, implementation implies just stop updating. 
         // But to disappear immediately, we might want to remove from Firestore.
         // _mapService.deleteUserLocation(user.uid); // If this method exists.
       }
    }
    // Update State to reflect UI (we reuse isGhostModeEnabled or add a new field?)
    // Actually we should map this to GhostMode or a new field.
    // Let's use isGhostModeEnabled inverted for now, OR better, 
    // since isGhost is persisted, we treat this toggle as the "Session Switch".
    
    // Changing state to reflect UI change (e.g. icon color)
    state = state.copyWith(isSharingActive: enable); 
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
    await initLocation();
  }

  void setDogFilters({
    List<DogSize>? sizes,
    List<DogGender>? genders,
    List<String>? breeds,
    bool? isSterilized,
  }) {
    state = state.copyWith(
      filterDogSizes: sizes,
      filterDogGenders: genders,
      filterDogBreeds: breeds,
      filterIsSterilized: isSterilized,
    );
     _updateMarkers();
  }

  void clearDogFilters() {
     state = state.copyWith(
       filterDogSizes: [],
       filterDogGenders: [],
       filterDogBreeds: [],
       filterIsSterilized: null,
     );
     _updateMarkers();
  }

  void setPetSpeciesFilter(List<PetSpecies> species) { // Changed to List
    state = state.copyWith(filterPetSpecies: species);
    _updateMarkers();
  }

  // ============================
  // PET BUSINESSES
  // ============================

  /// Load nearby pet businesses from Google Places API + Firestore
  Future<void> _loadNearbyPetBusinesses(Position position) async {
    try {
      print('[BIZ DEBUG] Starting _loadNearbyPetBusinesses lat=${position.latitude}, lng=${position.longitude}');
      final businesses = await _petBusinessService.fetchNearbyPetBusinesses(
        latitude: position.latitude,
        longitude: position.longitude,
        radiusInMeters: state.radiusInKm * 1000,
      );
      print('[BIZ DEBUG] Received ${businesses.length} businesses from service');
      if (businesses.isNotEmpty) {
        print('[BIZ DEBUG] First business: ${businesses.first.name} at (${businesses.first.latitude}, ${businesses.first.longitude})');
      }
      if (mounted) {
        state = state.copyWith(allPetBusinesses: businesses);
        print('[BIZ DEBUG] State updated with ${state.allPetBusinesses.length} businesses, showPetBusinesses=${state.showPetBusinesses}');
        _updateMarkers();
      } else {
        print('[BIZ DEBUG] NOT MOUNTED - skipping state update');
      }
    } catch (e, stack) {
      print('[BIZ DEBUG] ERROR loading pet businesses: $e');
      print('[BIZ DEBUG] Stack: $stack');
    }
  }

  /// Toggle pet business marker visibility
  void togglePetBusinesses(bool show) {
    state = state.copyWith(showPetBusinesses: show);
    // Load businesses on first enable (lazy load)
    if (show && state.allPetBusinesses.isEmpty && state.currentPosition != null) {
      _loadNearbyPetBusinesses(state.currentPosition!);
    }
    _updateMarkers();
  }

  /// Set business category filter (empty list = show all)
  void setBusinessCategoryFilter(List<PetBusinessCategory> categories) {
    state = state.copyWith(filterBusinessCategories: categories);
    _updateMarkers();
  }

  /// Select a pet business
  void selectPetBusiness(PetBusinessModel business) {
    state = state.copyWith(selectedPetBusiness: business);
  }

  /// Clear selected pet business
  void clearSelectedPetBusiness() {
    state = state.copyWith(selectedPetBusiness: null);
  }

  /// Refresh pet businesses (force re-fetch)
  Future<void> refreshPetBusinesses() async {
    _petBusinessService.clearCache();
    if (state.currentPosition != null) {
      await _loadNearbyPetBusinesses(state.currentPosition!);
    }
  }

  void _updateMarkers() {
    _markersDebounce?.cancel();
    _markersDebounce = Timer(const Duration(milliseconds: 100), () {
      _updateMarkersImpl();
    });
  }

  void _updateMarkersImpl() async {
    final thisVersion = ++_markersVersion;
    final List<Marker> markers = [];
    final query = state.searchQuery.toLowerCase();
    final Map<String, List<DogModel>> pendingCacheUpdates = {};
    
    // RADAR: Reset counts
    int newRadarCount = 0;
    List<String> newRadarMatchIds = [];

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
          // --- FILTER MATCHING LOGIC ---
          // Determine if user matches filters irrespective of visibility
          // We moved this UP to check before visibility for Radar purposes.
          
          // Filter by name (Search Bar) - Radar respects search too? Yes.
          if (query.isNotEmpty && !userProfile.fullName.toLowerCase().contains(query)) {
            continue;
          }

          // --- PET FILTERS (Global & Premium) ---
          final hasPremiumDogFilters = state.filterDogSizes.isNotEmpty || 
                                       state.filterDogGenders.isNotEmpty ||
                                       state.filterDogBreeds.isNotEmpty;

          final hasSpeciesFilter = state.filterPetSpecies.isNotEmpty; // Changed logic
          final hasDogFilters = hasPremiumDogFilters || hasSpeciesFilter;

          // Always fetch pets 
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
             
          if (dogsFetchedNow) {
             pendingCacheUpdates[userLoc.uid] = userDogs ?? [];
          }

          bool matchesFilters = true;

          if (hasDogFilters) {
             // 0. Empty check: If filtering by pets, user must HAVE pets.
             if (userDogs == null || userDogs.isEmpty) {
                matchesFilters = false;
             } else {
               // 1. Check Species Filter (Global)
               if (hasSpeciesFilter) {
                 // Multi-Selection Logic:
                 // The user dogs must contain ANY of the selected species?
                 // Or ALL? Usually "Show me Dogs OR Cats". So if I have a fish, I don't show up.
                 // If I have a Dog, I show up if Dog is selected.
                 
                 final hasMatchingSpecies = userDogs.any((pet) => state.filterPetSpecies.contains(pet.species));
                 if (!hasMatchingSpecies) matchesFilters = false;
               }

               // 2. Check Premium Filters (Dog Specific)
               if (matchesFilters && hasPremiumDogFilters) {
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

                    // Also check sterilized filter
                    bool isMatchWithSterilized(DogModel dog) {
                       if (!isMatch(dog)) return false;
                       if (state.filterIsSterilized != null && dog.isSterilized != state.filterIsSterilized) return false;
                       return true;
                    }
                    
                    if (!userDogs.any(isMatchWithSterilized)) matchesFilters = false;
               }
             }
          }
          
          if (!matchesFilters) continue; // Skip if doesn't match filters

          // 0. Ghost Mode Check (Hide invisible users)
          bool isVisible = true;
          if (userProfile.isGhost) isVisible = false;

          // Privacy Check
          final currentUserId = currentUser!.uid;
          if (isVisible) {
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
          }
          
          // RADAR LOGIC
          if (!isVisible) {
             // If invisible BUT matches filters, add to Radar
             newRadarCount++;
             newRadarMatchIds.add(userLoc.uid);
             continue; // Don't add marker
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
                child: _buildUserMarker(userProfile, userDogs ?? []),
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

      // Use SOS-style marker for lost pet announcements
      final isLost = announcement.category == AnnouncementCategory.lost;

      markers.add(
        Marker(
          point: LatLng(announcement.location.latitude, announcement.location.longitude),
          width: isLost ? 50 : 40,
          height: isLost ? 50 : 40,
          child: GestureDetector(
            onTap: () {
               state = state.copyWith(selectedAnnouncement: announcement);
            },
            child: isLost
                ? Container(
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)
                      ],
                    ),
                    child: const Icon(Icons.sos, color: Colors.white, size: 30),
                  )
                : Container(
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
          width: 50,
          height: 50,
          child: GestureDetector(
            onTap: () {
              state = state.copyWith(selectedSOS: sos);
            },
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.2),
              duration: const Duration(seconds: 1),
              builder: (context, value, child) {
                 return Transform.scale(scale: value, child: child);
              },
              onEnd: () {/* Loop handled elsewhere or stateless */}, 
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                     BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)
                  ]
                ),
                child: const Icon(Icons.sos, color: Colors.white, size: 30),
              ),
            ),
          ),
        ),
      );
    }

    // 5.5. Sighting Markers (Only visible to the owner of the lost pet)
    for (final sighting in state.allSightings) {
      markers.add(
        Marker(
          point: LatLng(sighting.latitude, sighting.longitude),
          width: 45,
          height: 45,
          child: GestureDetector(
            onTap: () {
              state = state.copyWith(selectedSighting: sighting);
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: const Icon(Icons.location_on, color: Colors.white, size: 24),
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

    // 7. Pet Business Markers
    final markersBeforeBusinesses = markers.length;
    print('[MAP DEBUG] showPetBusinesses=${state.showPetBusinesses}, allPetBusinesses.length=${state.allPetBusinesses.length}');
    if (state.showPetBusinesses) {
      for (final biz in state.allPetBusinesses) {
        // Category Filter
        if (state.filterBusinessCategories.isNotEmpty &&
            !state.filterBusinessCategories.contains(biz.category)) {
          continue;
        }

        // Search Filter
        if (query.isNotEmpty) {
          final matches = biz.name.toLowerCase().contains(query) ||
                          biz.category.displayName.toLowerCase().contains(query) ||
                          biz.address.toLowerCase().contains(query);
          if (!matches) continue;
        }

        markers.add(
          Marker(
            point: LatLng(biz.latitude, biz.longitude),
            width: 44,
            height: 44,
            child: GestureDetector(
              onTap: () {
                state = state.copyWith(selectedPetBusiness: biz);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: _petBusinessColor(biz.category),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: biz.isClaimed ? Colors.amber : Colors.white,
                    width: biz.isClaimed ? 3 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _petBusinessColor(biz.category).withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    _petBusinessIcon(biz.category),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    final businessMarkersAdded = markers.length - markersBeforeBusinesses;
    print('[MAP DEBUG] Business markers added: $businessMarkersAdded, total markers: ${markers.length}');

    if (mounted && _markersVersion == thisVersion) {
       final finalCache = Map<String, List<DogModel>>.from(state.dogCache);
       if (pendingCacheUpdates.isNotEmpty) {
          finalCache.addAll(pendingCacheUpdates);
       }
       state = state.copyWith(markers: markers, dogCache: finalCache);
       print('[MAP DEBUG] State updated with ${markers.length} markers (version $thisVersion)');
    } else {
       print('[MAP DEBUG] Discarding stale markers (version $thisVersion, current $_markersVersion)');
    }
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

  void clearSelectedSighting() { // Added
    state = state.copyWith(selectedSighting: null);
  }

  void clearSelectedEvent() { // Added
    state = state.copyWith(selectedEvent: null);
  }

  // Pet business marker icon helper
  static IconData _petBusinessIcon(PetBusinessCategory category) {
    switch (category) {
      case PetBusinessCategory.vetClinic:
        return Icons.local_hospital;
      case PetBusinessCategory.petShop:
        return Icons.shopping_bag;
      case PetBusinessCategory.groomer:
        return Icons.content_cut;
      case PetBusinessCategory.petSitter:
        return Icons.home;
      case PetBusinessCategory.dogTrainer:
        return Icons.school;
      case PetBusinessCategory.petHotel:
        return Icons.hotel;
      case PetBusinessCategory.petFriendlyCafe:
        return Icons.coffee;
      case PetBusinessCategory.petPharmacy:
        return Icons.local_pharmacy;
      case PetBusinessCategory.dogPark:
        return Icons.park;
      case PetBusinessCategory.petFriendlyBeach:
        return Icons.beach_access;
      case PetBusinessCategory.petFriendlyBathhouse:
        return Icons.beach_access;
      case PetBusinessCategory.other:
        return Icons.store;
    }
  }

  // Pet business marker color helper
  static Color _petBusinessColor(PetBusinessCategory category) {
    switch (category) {
      case PetBusinessCategory.vetClinic:
        return const Color(0xFFE53935); // Red
      case PetBusinessCategory.petShop:
        return const Color(0xFF00897B); // Teal
      case PetBusinessCategory.groomer:
        return const Color(0xFF8E24AA); // Purple
      case PetBusinessCategory.petSitter:
        return const Color(0xFF1E88E5); // Blue
      case PetBusinessCategory.dogTrainer:
        return const Color(0xFFF4511E); // Deep Orange
      case PetBusinessCategory.petHotel:
        return const Color(0xFF3949AB); // Indigo
      case PetBusinessCategory.petFriendlyCafe:
        return const Color(0xFF6D4C41); // Brown
      case PetBusinessCategory.petPharmacy:
        return const Color(0xFF00ACC1); // Cyan
      case PetBusinessCategory.dogPark:
        return const Color(0xFF43A047); // Green
      case PetBusinessCategory.petFriendlyBeach:
        return const Color(0xFFFFB300); // Amber
      case PetBusinessCategory.petFriendlyBathhouse:
        return const Color(0xFFFF8F00); // Dark Amber
      case PetBusinessCategory.other:
        return const Color(0xFF757575); // Grey
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _nearbyUsersSubscription?.cancel();
    _walksSubscription?.cancel();
    _announcementsSubscription?.cancel();
    _alertsSubscription?.cancel();
    _sosSubscription?.cancel(); // Added
    _sightingsSubscription?.cancel(); // Added
    _eventsSubscription?.cancel(); // Added
    _markersDebounce?.cancel();
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
            final queryAddress = (userModel.address != null && userModel.address!.isNotEmpty)
                ? userModel.address!
                : userModel.zone;
            if (queryAddress.isNotEmpty) {
              print('Attempting to geocode address/zone: $queryAddress, Italia');
              final locations = await locationFromAddress('$queryAddress, Italia');
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

  Widget _buildUserMarker(UserModel user, List<DogModel> pets) {
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
             child: const Icon(Icons.store, color: Colors.white, size: 24),
          );
      }
      
      // Use Custom Marker Icon from MapMarkers
      // The mapMarkerId in UserModel stores the selected icon ID
      // If pets are passed, we could use them for logic later, but for now we prioritize the user's selected avatar
      final iconData = MapMarkers.getIcon(user.mapMarkerId);

      return Container(
        decoration: BoxDecoration(
           color: Colors.deepPurple, // Brand color background
           shape: BoxShape.circle,
           border: Border.all(color: Colors.white, width: 2), 
           boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))
           ]
        ),
        child: Center(
          child: Icon(iconData, color: Colors.white, size: 28), // White icon on colored background
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
    ref.watch(dogServiceProvider),
    ref.watch(petBusinessServiceProvider),
    ref,
  );
});
