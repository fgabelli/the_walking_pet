import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart'; // For Uint8List
import '../../shared/models/ad_campaign_model.dart';
import 'dart:math';

class AdService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches a single active ad for a specific zone.
  /// Uses a simple randomization strategy to rotate ads.
  Future<AdCampaignModel?> fetchNativeAd(String zone) async {
    try {
      final now = DateTime.now();
      
      // Query active ads for the zone not expired
      final querySnapshot = await _firestore
          .collection('ads')
          .where('targetZone', isEqualTo: zone)
          .where('isActive', isEqualTo: true)
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
          .get();

      if (querySnapshot.docs.isEmpty) {
        // Fallback: Check for 'global' ads if zone specific not found
        final globalQuery = await _firestore
          .collection('ads')
          .where('targetZone', isEqualTo: 'global')
          .where('isActive', isEqualTo: true)
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
          .get();
          
        if (globalQuery.docs.isEmpty) return null;
        
        // Pick random global ad
        final random = Random();
        final doc = globalQuery.docs[random.nextInt(globalQuery.docs.length)];
        return AdCampaignModel.fromFirestore(doc);
      }

      // Pick a random ad from the results to distribute impressions
      final random = Random();
      final doc = querySnapshot.docs[random.nextInt(querySnapshot.docs.length)];
      
      return AdCampaignModel.fromFirestore(doc);
    } catch (e) {
      print('Error fetching native ad: $e');
      return null;
    }
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
}
