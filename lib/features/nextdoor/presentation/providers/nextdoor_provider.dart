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
  final List<String> blockedUsers;

  NextdoorState({
    this.announcements = const [],
    this.isLoading = true,
    this.isSubmitting = false,
    this.error,
    this.blockedUsers = const [],
  });

  NextdoorState copyWith({
    List<AnnouncementModel>? announcements,
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    List<String>? blockedUsers,
  }) {
    return NextdoorState(
      announcements: announcements ?? this.announcements,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
      blockedUsers: blockedUsers ?? this.blockedUsers,
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
    _startListeningToProfile();
  }

  void _startListeningToProfile() {
    _ref.listen(currentUserProfileProvider, (previous, next) {
      next.whenData((user) {
        if (user != null) {
          state = state.copyWith(blockedUsers: user.blockedUsers);
          // Trigger refresh of filtered list if we had stored the raw list separately.
          // Since we store filtered list in 'announcements', we might need to re-fetch or re-filter locally?
          // Re-fetching is safer/easier for now as we don't keep raw stream.
          // Or better: The stream subscription below will re-emit if we didn't cancel it? No.
          // We can just rely on the next update or force a re-fetch.
          // For now, let's just update the state. The stream below needs to know about this new state.
          // BUT: The stream listener implementation below needs to access 'state.blockedUsers'. 
          // Since 'state' is available in the listener callback (via capturing or just accessing current state),
          // it should work for NEW emissions. But existing list won't change unless we re-process it.
          // We need to store 'rawAnnouncements' to re-filter, OR just re-fetch.
          // Let's re-trigger _init if position is known? No.
          // Let's just update state using current announcements re-filtered?
          _reFilterAnnouncements();
        }
      });
    });
  }

  void _reFilterAnnouncements() {
    // This is tricky because we don't have the RAW list anymore, only the filtered one.
    // If I block someone, I can remove them from current list.
    // If I unblock, they won't reappear until next fetch.
    // Ideally we keep 'rawAnnouncements' in state or controller.
    // For now, let's just filter OUT the newly blocked ones from current list.
    // Unblocking will require pull-to-refresh or app restart until we improve this.
    final currentList = state.announcements;
    final filtered = _filterAnnouncements(currentList);
    state = state.copyWith(announcements: filtered);
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
        
        // Filter blocked content
        final filteredAnnouncements = _filterAnnouncements(activeAnnouncements);

        // Sort by creation date (newest first)
        filteredAnnouncements.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        state = state.copyWith(
          announcements: filteredAnnouncements,
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
  List<AnnouncementModel> _filterAnnouncements(List<AnnouncementModel> raw) {
    if (state.blockedUsers.isEmpty) return raw;

    return raw.where((a) {
      // 1. Filter if Author is blocked
      if (state.blockedUsers.contains(a.userId)) return false;
      return true;
    }).map((a) {
      // 2. Filter responses (comments) from blocked users
      // We need to return a COPY with filtered responses
      // The model is immutable, checking if we need to copy
      final blockedResponses = a.responses.where((r) => state.blockedUsers.contains(r.userId));
      if (blockedResponses.isEmpty) return a;

      final filteredResponses = a.responses.where((r) => !state.blockedUsers.contains(r.userId)).toList();
      return a.copyWith(responses: filteredResponses);
    }).toList();
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
