import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; // For Uint8List
import '../../shared/models/ad_campaign_model.dart';
import 'dart:math';

class AdService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches a single active ad for a specific zone with location targeting.
  /// Uses a simple randomization strategy to rotate ads.
  Future<AdCampaignModel?> fetchNativeAd(String zone, {String? userCity, String? userRegion, double? userLatitude, double? userLongitude}) async {
    try {
      final now = DateTime.now();
      
      bool isMatch(AdCampaignModel ad) {
        if (ad.targetingType == 'regional') {
          if (userRegion == null || ad.targetRegion == null) return false;
          return ad.targetRegion!.trim().toLowerCase() == userRegion.trim().toLowerCase();
        } else if (ad.targetingType == 'local') {
          // Check distance if coordinates and radius are available
          if (ad.targetLatitude != null &&
              ad.targetLongitude != null &&
              ad.targetRadiusKm != null &&
              ad.targetRadiusKm! > 0 &&
              userLatitude != null &&
              userLongitude != null) {
            final distance = _calculateDistance(
              userLatitude,
              userLongitude,
              ad.targetLatitude!,
              ad.targetLongitude!,
            );
            return distance <= ad.targetRadiusKm!;
          }

          // Fallback: Exact name-based match
          if (userCity == null || ad.targetCity == null) return false;
          return ad.targetCity!.trim().toLowerCase() == userCity.trim().toLowerCase();
        }
        return true; // 'national' or default is visible to everyone
      }

      // Query active ads for the zone.
      final querySnapshot = await _firestore
          .collection('ads')
          .where('targetZone', isEqualTo: zone)
          .where('isActive', isEqualTo: true)
          .get();

      List<AdCampaignModel> validDocs = querySnapshot.docs
          .map((d) => AdCampaignModel.fromFirestore(d))
          .where((ad) => ad.startDate.isBefore(now) && ad.endDate.isAfter(now) && isMatch(ad))
          .toList();

      if (validDocs.isEmpty && zone != 'global') {
        // Fallback: Check for 'global' ads if zone specific not found/matching
        final globalQuery = await _firestore
            .collection('ads')
            .where('targetZone', isEqualTo: 'global')
            .where('isActive', isEqualTo: true)
            .get();
            
        validDocs = globalQuery.docs
            .map((d) => AdCampaignModel.fromFirestore(d))
            .where((ad) => ad.startDate.isBefore(now) && ad.endDate.isAfter(now) && isMatch(ad))
            .toList();
      }

      if (validDocs.isEmpty) {
        return null;
      }

      // Pick a random ad from the results to distribute impressions
      final random = Random();
      final ad = validDocs[random.nextInt(validDocs.length)];
      
      return ad;
    } catch (e) {
      print('Error fetching native ad: $e');
      return null;
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) *
        (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  /// Records an impression (View)
  Future<void> recordImpression(String adId) async {
    try {
      await _firestore.collection('ads').doc(adId).update({
        'impressions': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error recording impression: $e');
    }
  }

  /// Records a click
  Future<void> recordClick(String adId) async {
    try {
      await _firestore.collection('ads').doc(adId).update({
        'clicks': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error recording click: $e');
    }
  }
  
  /// Create a new campaign (Admin/Business usage)
  Future<void> createCampaign(AdCampaignModel ad) async {
    await _firestore.collection('ads').add(ad.toMap());
  }

  /// Update an existing campaign
  Future<void> updateCampaign(AdCampaignModel ad) async {
    // Cannot update without a valid ID. In our model, we might have empty id from create, but from query it is populated.
    if (ad.id.isNotEmpty) {
      await _firestore.collection('ads').doc(ad.id).update(ad.toMap());
    }
  }

  /// Get ALL ads (Admin)
  Stream<List<AdCampaignModel>> getAllAdsStream() {
    return _firestore
        .collection('ads')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => AdCampaignModel.fromFirestore(doc)).toList();
    });
  }

  /// Toggle Active Status
  Future<void> toggleAdStatus(String adId, bool isActive) async {
    await _firestore.collection('ads').doc(adId).update({'isActive': isActive});
  }

  /// Delete Ad
  Future<void> deleteAd(String adId) async {
    await _firestore.collection('ads').doc(adId).delete();
  }

  /// Upload Ad Image (Web compatible)
  Future<String> uploadAdImage(Uint8List bytes, String fileName) async {
    final ref = FirebaseStorage.instance.ref().child('ads_images/$fileName');
    // Set metadata for caching if needed
    final snapshot = await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return await snapshot.ref.getDownloadURL();
  }

  /// Upload Ad Video (Web compatible)
  Future<String> uploadAdVideo(Uint8List bytes, String fileName) async {
    final ref = FirebaseStorage.instance.ref().child('ads_videos/$fileName');
    final snapshot = await ref.putData(bytes, SettableMetadata(contentType: 'video/mp4'));
    return await snapshot.ref.getDownloadURL();
  }
}
