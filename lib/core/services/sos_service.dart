import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/lost_pet_alert_model.dart'; // Added
import '../../shared/models/lost_pet_sighting_model.dart';

class SOSService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Trigger SOS - returns the alert document ID
  Future<String> triggerSOS({
    required String ownerId,
    required String petId,
    required double latitude,
    required double longitude,
    required String contactPhone,
    String? message,
  }) async {
    final alert = LostPetAlertModel(
      id: '', // Generated
      ownerId: ownerId,
      petId: petId,
      latitude: latitude,
      longitude: longitude,
      contactPhone: contactPhone,
      message: message,
      createdAt: DateTime.now(),
      isActive: true,
    );

    final docRef = await _firestore.collection('lost_pet_alerts').add(alert.toFirestore());
    return docRef.id;
  }

  // Link SOS alert to its bacheca announcement for comment support
  Future<void> linkAnnouncement(String alertId, String announcementId) async {
    await _firestore.collection('lost_pet_alerts').doc(alertId).update({
      'announcementId': announcementId,
    });
  }

  // Resolve SOS (Mark inactive)
  Future<void> resolveSOS(String alertId) async {
    await _firestore.collection('lost_pet_alerts').doc(alertId).update({'isActive': false});
  }

  // Get Active SOS Stream — only shows alerts from the last 72 hours
  Stream<List<LostPetAlertModel>> getActiveSOSStream() {
    return _firestore
        .collection('lost_pet_alerts')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final cutoff = DateTime.now().subtract(const Duration(hours: 72));
      return snapshot.docs
          .map((doc) => LostPetAlertModel.fromFirestore(doc))
          .where((alert) => alert.createdAt.isAfter(cutoff))
          .toList();
    });
  }

  // Add sighting for a lost pet
  Future<String> addSighting({
    required String alertId,
    required String petId,
    required String ownerId,
    required String finderId,
    required double latitude,
    required double longitude,
    required String photoUrl,
    required String description,
  }) async {
    final sighting = LostPetSightingModel(
      id: '',
      alertId: alertId,
      petId: petId,
      ownerId: ownerId,
      finderId: finderId,
      latitude: latitude,
      longitude: longitude,
      photoUrl: photoUrl,
      description: description,
      createdAt: DateTime.now(),
    );
    final docRef = await _firestore.collection('lost_pet_sightings').add(sighting.toFirestore());
    return docRef.id;
  }

  // Get sightings stream for a specific owner
  Stream<List<LostPetSightingModel>> getSightingsForOwnerStream(String ownerId) {
    return _firestore
        .collection('lost_pet_sightings')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => LostPetSightingModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }
}

final sosServiceProvider = Provider<SOSService>((ref) => SOSService());
