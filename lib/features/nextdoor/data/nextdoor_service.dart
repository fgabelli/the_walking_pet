import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import '../../../../shared/models/announcement_model.dart';

class NextdoorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'announcements';

  // Create announcement
  Future<String> createAnnouncement(AnnouncementModel announcement, {File? imageFile}) async {
    try {
      // 1. Add to Firestore to get ID
      final docRef = await _firestore.collection(_collection).add(announcement.toFirestore());
      final announcementId = docRef.id;

      // 2. Upload image if exists
      if (imageFile != null) {
        // We need StorageService here. 
        // Ideally, the service shouldn't depend on another service directly if not injected.
        // But for simplicity, let's assume the caller handles the upload or we inject it.
        // Actually, let's stick to the pattern used in DogProvider: Controller orchestrates services.
        // So NextdoorService just handles Firestore.
        // WAIT: The plan said "Update createAnnouncement to accept an optional File? imageFile and handle upload".
        // But NextdoorService doesn't have StorageService injected.
        // Let's modify the plan slightly: The Controller will handle the upload using StorageService, then update the announcement.
        // OR we can inject StorageService into NextdoorService.
        // Let's keep NextdoorService focused on Firestore and handle orchestration in the Controller.
        // So this method just returns the ID.
        return announcementId;
      }
      
      return announcementId;
    } catch (e) {
      rethrow;
    }
  }

  // Update announcement
  Future<void> updateAnnouncement(AnnouncementModel announcement) async {
    try {
      await _firestore.collection(_collection).doc(announcement.id).update(announcement.toFirestore());
    } catch (e) {
      rethrow;
    }
  }

  // Get announcements nearby
  Stream<List<AnnouncementModel>> getNearbyAnnouncements({
    required double latitude,
    required double longitude,
    required double radiusInKm,
  }) {
    final center = GeoFirePoint(GeoPoint(latitude, longitude));
    final collectionReference = _firestore.collection(_collection);

    // GeoFlutterFire Plus query
    return GeoCollectionReference(collectionReference).subscribeWithin(
      center: center,
      radiusInKm: radiusInKm,
      field: 'location',
      geopointFrom: (data) {
        final location = data['location'] as Map<String, dynamic>;
        if (location['geopoint'] != null) {
          return location['geopoint'] as GeoPoint;
        }
        // Fallback for legacy data
        return GeoPoint(
          (location['latitude'] as num?)?.toDouble() ?? 0.0,
          (location['longitude'] as num?)?.toDouble() ?? 0.0,
        );
      },
      strictMode: true,
    ).map((snapshots) => snapshots
        .map((doc) => AnnouncementModel.fromFirestore(doc))
        .toList());
  }

  // Add response to announcement
  Future<void> addResponse(String announcementId, AnnouncementResponse response) async {
    try {
      await _firestore.collection(_collection).doc(announcementId).update({
        'responses': FieldValue.arrayUnion([response.toMap()]),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Delete announcement
  Future<void> deleteAnnouncement(String announcementId) async {
    try {
      await _firestore.collection(_collection).doc(announcementId).delete();
    } catch (e) {
      rethrow;
    }
  }
}
