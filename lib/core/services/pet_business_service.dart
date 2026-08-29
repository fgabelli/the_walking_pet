
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/pet_business_model.dart';

/// Provider
final petBusinessServiceProvider = Provider<PetBusinessService>((ref) {
  return PetBusinessService();
});

class PetBusinessService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'pet_businesses';

  // Cache to avoid repeated Cloud Function calls
  final Map<String, List<PetBusinessModel>> _nearbyCache = {};
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(hours: 6);

  // ============================
  // NEARBY SEARCH VIA CLOUD FUNCTION
  // ============================

  /// Fetch pet-related businesses near a location via Cloud Function proxy
  /// The Cloud Function calls Google Places API server-side (no IP restrictions)
  Future<List<PetBusinessModel>> fetchNearbyPetBusinesses({
    required double latitude,
    required double longitude,
    double radiusInMeters = 5000, // 5km default
  }) async {
    // Cache check
    final cacheKey = '${latitude.toStringAsFixed(2)}_${longitude.toStringAsFixed(2)}';
    if (_nearbyCache.containsKey(cacheKey) &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      return _nearbyCache[cacheKey]!;
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'nearbyPetBusinesses',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );

      final result = await callable.call<Map<String, dynamic>>({
        'latitude': latitude,
        'longitude': longitude,
        'radiusInMeters': radiusInMeters,
      });

      final data = result.data;
      final rawList = data['results'] as List<dynamic>? ?? [];
      print('[PetBusinessService] Raw results count: ${rawList.length}');

      final List<PetBusinessModel> businesses = [];
      for (final item in rawList) {
        try {
          final place = Map<String, dynamic>.from(item as Map);
          businesses.add(PetBusinessModel(
            id: place['placeId']?.toString() ?? '',
            googlePlaceId: place['placeId']?.toString(),
            name: place['name']?.toString() ?? 'Sconosciuto',
            address: place['address']?.toString() ?? '',
            latitude: (place['lat'] as num?)?.toDouble() ?? 0.0,
            longitude: (place['lng'] as num?)?.toDouble() ?? 0.0,
            category: _categoryFromString(place['category']?.toString() ?? 'other'),
            rating: (place['rating'] as num?)?.toDouble(),
            userRatingsTotal: (place['userRatingsTotal'] as num?)?.toInt(),
            openNow: place['openNow']?.toString(),
          ));
        } catch (e) {
          print('[PetBusinessService] Error parsing place item: $e - item: $item');
        }
      }

      print('[PetBusinessService] Parsed ${businesses.length} businesses');

      // Merge with Firestore data (claimed businesses may have richer info)
      final enriched = await _mergeWithFirestore(businesses);

      // Update cache
      _nearbyCache[cacheKey] = enriched;
      _lastFetchTime = DateTime.now();

      print('Loaded ${enriched.length} pet businesses via Cloud Function');
      return enriched;
    } catch (e, stack) {
      print('Error fetching pet businesses via Cloud Function: $e');
      print('Stack: $stack');
      // Fallback: try loading from Firestore only
      try {
        final snapshot = await _firestore.collection(_collection).get();
        return snapshot.docs.map((doc) => PetBusinessModel.fromFirestore(doc)).toList();
      } catch (_) {
        return [];
      }
    }

  }

  /// Map category string from Cloud Function to enum
  PetBusinessCategory _categoryFromString(String category) {
    switch (category) {
      case 'vetClinic': return PetBusinessCategory.vetClinic;
      case 'petShop': return PetBusinessCategory.petShop;
      case 'groomer': return PetBusinessCategory.groomer;
      case 'petSitter': return PetBusinessCategory.petSitter;
      case 'dogTrainer': return PetBusinessCategory.dogTrainer;
      case 'petHotel': return PetBusinessCategory.petHotel;
      case 'petFriendlyCafe': return PetBusinessCategory.petFriendlyCafe;
      case 'petPharmacy': return PetBusinessCategory.petPharmacy;
      case 'dogPark': return PetBusinessCategory.dogPark;
      case 'petFriendlyBeach': return PetBusinessCategory.petFriendlyBeach;
      case 'petFriendlyBathhouse': return PetBusinessCategory.petFriendlyBathhouse;
      default: return PetBusinessCategory.other;
    }
  }

  // ============================
  // FIRESTORE OPERATIONS
  // ============================

  /// Merge Google Places results with any existing Firestore data
  Future<List<PetBusinessModel>> _mergeWithFirestore(List<PetBusinessModel> googleResults) async {
    if (googleResults.isEmpty) return googleResults;

    final placeIds = googleResults
        .where((b) => b.googlePlaceId != null)
        .map((b) => b.googlePlaceId!)
        .toList();

    if (placeIds.isEmpty) return googleResults;

    // Firestore 'whereIn' supports max 30 items
    final List<PetBusinessModel> merged = List.from(googleResults);
    
    for (var i = 0; i < placeIds.length; i += 30) {
      final batch = placeIds.sublist(i, i + 30 > placeIds.length ? placeIds.length : i + 30);
      try {
        final snapshot = await _firestore
            .collection(_collection)
            .where('googlePlaceId', whereIn: batch)
            .get();

        for (final doc in snapshot.docs) {
          final firestoreBiz = PetBusinessModel.fromFirestore(doc);
          // Replace Google result with richer Firestore data
          final index = merged.indexWhere((b) => b.googlePlaceId == firestoreBiz.googlePlaceId);
          if (index != -1) {
            merged[index] = firestoreBiz;
          }
        }
      } catch (e) {
        print('Error merging with Firestore: $e');
      }
    }

    // Also fetch manually-added businesses (no Google Place ID)
    // These are businesses added directly by owners
    try {
      final manualSnapshot = await _firestore
          .collection(_collection)
          .where('googlePlaceId', isNull: true)
          .limit(50)
          .get();
      
      for (final doc in manualSnapshot.docs) {
        final biz = PetBusinessModel.fromFirestore(doc);
        if (!merged.any((b) => b.id == biz.id)) {
          merged.add(biz);
        }
      }
    } catch (e) {
      print('Error fetching manual businesses: $e');
    }

    return merged;
  }

  /// Save or update a business in Firestore
  Future<void> saveBusiness(PetBusinessModel business) async {
    await _firestore
        .collection(_collection)
        .doc(business.id)
        .set(business.toFirestore(), SetOptions(merge: true));
  }

  /// Claim a business (only if the category allows it)
  Future<bool> claimBusiness({
    required String businessId,
    required String userId,
    required String googlePlaceId,
  }) async {
    // First, ensure the business exists in Firestore
    final docRef = _firestore.collection(_collection).doc(businessId);
    final doc = await docRef.get();
    
    if (doc.exists) {
      final biz = PetBusinessModel.fromFirestore(doc);
      // Prevent claiming public spaces (e.g. dog parks)
      if (!biz.category.canBeClaimed) {
        print('Cannot claim a ${biz.category.displayName} - public space');
        return false;
      }
      // Update existing
      await docRef.update({
        'isClaimed': true,
        'claimedByUserId': userId,
        'claimedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } else {
      // This shouldn't happen normally - business should be saved first
      print('Warning: Trying to claim non-existent business $businessId');
      return false;
    }
  }

  /// Get a single business by ID
  Future<PetBusinessModel?> getBusinessById(String id) async {
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (doc.exists) {
      return PetBusinessModel.fromFirestore(doc);
    }
    return null;
  }

  /// Get businesses claimed by a user
  Future<List<PetBusinessModel>> getBusinessesByOwner(String userId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('claimedByUserId', isEqualTo: userId)
        .get();

    return snapshot.docs
        .map((doc) => PetBusinessModel.fromFirestore(doc))
        .toList();
  }

  /// Get Google Places details for a place via Cloud Function proxy
  Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'placeDetails',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
      );

      final result = await callable.call<Map<String, dynamic>?>({
        'placeId': placeId,
      });

      return result.data;
    } catch (e) {
      print('Error fetching place details via Cloud Function: $e');
    }
    return null;
  }

  /// Clear cache (useful when location changes significantly)
  void clearCache() {
    _nearbyCache.clear();
    _lastFetchTime = null;
  }

  /// Submit a business claim request for admin review
  Future<void> submitBusinessClaim({
    required String businessId,
    required String businessName,
    String? googlePlaceId,
    required String userId,
    required String ownerName,
    required String role,
    required String businessEmail,
    required String piva,
    required String phone,
    String? notes,
    String? proofPhotoUrl,
  }) async {
    // First ensure the business exists in Firestore
    final bizDoc = await _firestore.collection(_collection).doc(businessId).get();
    if (!bizDoc.exists && googlePlaceId != null) {
      // Save the business shell from Google Places data
      await _firestore.collection(_collection).doc(businessId).set({
        'googlePlaceId': googlePlaceId,
        'name': businessName,
        'isClaimed': false,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await _firestore.collection('business_claims').add({
      'businessId': businessId,
      'businessName': businessName,
      'googlePlaceId': googlePlaceId,
      'userId': userId,
      'ownerName': ownerName,
      'role': role,
      'businessEmail': businessEmail,
      'piva': piva,
      'phone': phone,
      'notes': notes,
      'proofPhotoUrl': proofPhotoUrl,
      'status': 'pending', // pending, approved, rejected
      'createdAt': FieldValue.serverTimestamp(),
      'reviewedAt': null,
      'reviewedBy': null,
      'rejectionReason': null,
    });
  }

  /// Check if a user already has a pending/approved claim for a business
  Future<String?> getClaimStatus({
    required String businessId,
    required String userId,
  }) async {
    final snapshot = await _firestore
        .collection('business_claims')
        .where('businessId', isEqualTo: businessId)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.data()['status'] as String?;
  }
}
