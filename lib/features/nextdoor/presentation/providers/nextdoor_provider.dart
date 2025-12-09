import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../shared/models/announcement_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/nextdoor_service.dart';
import '../../../map/presentation/providers/map_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart'; // For storageServiceProvider

/// Nextdoor Service Provider
final nextdoorServiceProvider = Provider<NextdoorService>((ref) {
  return NextdoorService();
});

/// Nextdoor State
class NextdoorState {
  final List<AnnouncementModel> announcements;
  final bool isLoading;
  final bool isSubmitting;
  final String? error;

  NextdoorState({
    this.announcements = const [],
    this.isLoading = true,
    this.isSubmitting = false,
    this.error,
  });

  NextdoorState copyWith({
    List<AnnouncementModel>? announcements,
    bool? isLoading,
    bool? isSubmitting,
    String? error,
  }) {
    return NextdoorState(
      announcements: announcements ?? this.announcements,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
    );
  }
}

/// Nextdoor Controller
class NextdoorController extends StateNotifier<NextdoorState> {
  final NextdoorService _nextdoorService;
  final LocationService _locationService;
  final StorageService _storageService; // Add this
  final Ref _ref;

  NextdoorController(
    this._nextdoorService,
    this._locationService,
    this._storageService, // Add this
    this._ref,
  ) : super(NextdoorState()) {
    _init();
  }

  void _init() async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        _startListening(position);
      } else {
        state = state.copyWith(isLoading: false, error: 'Posizione non disponibile');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _startListening(Position position) {
    _nextdoorService
        .getNearbyAnnouncements(
      latitude: position.latitude,
      longitude: position.longitude,
      radiusInKm: 10.0, // 10km radius for announcements
    )
        .listen(
      (announcements) {
        // Filter expired announcements
        final activeAnnouncements = announcements.where((a) => a.isActive).toList();
        // Sort by creation date (newest first)
        activeAnnouncements.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        state = state.copyWith(
          announcements: activeAnnouncements,
          isLoading: false,
        );
      },
      onError: (e) {
        state = state.copyWith(isLoading: false, error: e.toString());
      },
    );
  }

  Future<void> createAnnouncement({
    required String message,
    required String zone,
    required int durationInHours,
    File? imageFile,
    double? latitude,
    double? longitude,
  }) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final user = _ref.read(authServiceProvider).currentUser;
      if (user == null) throw Exception('Utente non autenticato');

      double lat, lng;
      if (latitude != null && longitude != null) {
        lat = latitude;
        lng = longitude;
      } else {
        final position = await _locationService.getCurrentPosition();
        if (position == null) throw Exception('Posizione non disponibile');
        lat = position.latitude;
        lng = position.longitude;
      }

      final now = DateTime.now();
      final expiresAt = now.add(Duration(hours: durationInHours));

      // Fetch user profile for author info
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      final authorName = userData != null ? '${userData['firstName']} ${userData['lastName']}' : 'Utente';
      final authorPhotoUrl = userData?['photoUrl'];

      // Calculate geohash
      final geoFirePoint = GeoFirePoint(GeoPoint(lat, lng));

      // 1. Create announcement object
      final announcement = AnnouncementModel(
        id: '', // Will be set by Firestore
        userId: user.uid,
        message: message,
        zone: zone,
        location: AnnouncementLocation(
          latitude: lat,
          longitude: lng,
          geohash: geoFirePoint.geohash,
        ),
        responses: [],
        authorName: authorName,
        authorPhotoUrl: authorPhotoUrl,
        createdAt: now,
        expiresAt: expiresAt,
      );

      // 2. Save to Firestore to get ID
      final announcementId = await _nextdoorService.createAnnouncement(announcement);

      // 3. Upload image if exists
      String? imageUrl;
      if (imageFile != null) {
        imageUrl = await _storageService.uploadAnnouncementImage(announcementId, imageFile);
        
        // 4. Update announcement with image URL and ID
        final updatedAnnouncement = announcement.copyWith(
          id: announcementId,
          imageUrl: imageUrl,
        );
        await _nextdoorService.updateAnnouncement(updatedAnnouncement);
      } else {
         // Just update ID if no image (though createAnnouncement returned ID, the model needs it if we were to use it locally, but we rely on stream)
         // Actually, createAnnouncement in service just adds it. We might want to update the ID in the doc if we want the doc to contain its own ID, but Firestore doc ID is usually separate.
         // However, our model has an 'id' field. It's good practice to ensure it matches.
         // But for now, let's just leave it as is if no image, or update it if we want consistency.
      }

      state = state.copyWith(isSubmitting: false);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      rethrow;
    }

  }

  Future<void> updateAnnouncement(AnnouncementModel announcement, {File? newImage, double? latitude, double? longitude}) async {
    state = state.copyWith(isSubmitting: true);
    try {
      String? imageUrl = announcement.imageUrl;
      
      if (newImage != null) {
        imageUrl = await _storageService.uploadAnnouncementImage(announcement.id, newImage);
      }

      AnnouncementModel updatedAnnouncement = announcement.copyWith(imageUrl: imageUrl);

      // Update location if provided
      if (latitude != null && longitude != null) {
        final geoFirePoint = GeoFirePoint(GeoPoint(latitude, longitude));
        updatedAnnouncement = updatedAnnouncement.copyWith(
          location: AnnouncementLocation(
            latitude: latitude,
            longitude: longitude,
            geohash: geoFirePoint.geohash,
          ),
        );
      }

      await _nextdoorService.updateAnnouncement(updatedAnnouncement);

      state = state.copyWith(isSubmitting: false);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> deleteAnnouncement(String announcementId) async {
    state = state.copyWith(isSubmitting: true);
    try {
      await _nextdoorService.deleteAnnouncement(announcementId);
      state = state.copyWith(isSubmitting: false);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> addResponse(String announcementId, ResponseType type, {String? message}) async {
    try {
      final user = _ref.read(authServiceProvider).currentUser;
      if (user == null) return;

      // Fetch user profile
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      final userName = userData != null ? '${userData['firstName']} ${userData['lastName']}' : 'Utente';
      final userPhotoUrl = userData?['photoUrl'];

      final response = AnnouncementResponse(
        userId: user.uid,
        userName: userName,
        userPhotoUrl: userPhotoUrl,
        type: type,
        message: message,
        timestamp: DateTime.now(),
      );

      await _nextdoorService.addResponse(announcementId, response);
    } catch (e) {
      // Handle error silently or show snackbar in UI
      print('Error adding response: $e');
    }
  }
}

/// Nextdoor Controller Provider
final nextdoorControllerProvider =
    StateNotifierProvider<NextdoorController, NextdoorState>((ref) {
  return NextdoorController(
    ref.watch(nextdoorServiceProvider),
    ref.watch(locationServiceProvider),
    ref.watch(storageServiceProvider), // Add this
    ref,
  );
});
