import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final matcherServiceProvider = Provider<MatcherService>((ref) => MatcherService());

class MatcherService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _swipesCollection => _firestore.collection('pet_swipes');
  CollectionReference get _matchesCollection => _firestore.collection('pet_matches');

  /// Saves a swipe action (like or pass).
  /// If it's a mutual 'like', registers a match and returns true.
  Future<bool> swipePet({
    required String senderPetId,
    required String targetPetId,
    required String senderUid,
    required String targetUid,
    required bool isLike,
  }) async {
    final swipeData = {
      'senderPetId': senderPetId,
      'targetPetId': targetPetId,
      'senderUid': senderUid,
      'targetUid': targetUid,
      'isLike': isLike,
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Save the swipe
    await _swipesCollection.add(swipeData);

    if (!isLike) return false;

    // Check for mutual like
    try {
      debugPrint('[MatcherService] Checking mutual like: sender=$senderPetId, target=$targetPetId');
      final oppositeSwipe = await _swipesCollection
          .where('senderPetId', isEqualTo: targetPetId)
          .where('targetPetId', isEqualTo: senderPetId)
          .where('isLike', isEqualTo: true)
          .limit(1)
          .get();

      debugPrint('[MatcherService] Opposite swipe docs found: ${oppositeSwipe.docs.length}');

      if (oppositeSwipe.docs.isNotEmpty) {
        // It's a match! Create match document
        debugPrint('[MatcherService] MATCH DETECTED! Creating match document...');
        final matchData = {
          'petIds': [senderPetId, targetPetId],
          'uids': [senderUid, targetUid],
          'createdAt': FieldValue.serverTimestamp(),
        };
        await _matchesCollection.add(matchData);
        debugPrint('[MatcherService] Match document created successfully');
        return true;
      }
    } catch (e, stackTrace) {
      debugPrint('[MatcherService] ERROR checking mutual like: $e');
      debugPrint('[MatcherService] Stack trace: $stackTrace');
      // If the composite index is missing, Firestore throws a FirebaseException.
      // Log the full error so we can see the index creation link in the console.
    }

    return false;
  }

  /// Get the list of all pet IDs that this pet has already swiped
  Future<List<String>> getSwipedPetIds(String senderPetId) async {
    final snapshot = await _swipesCollection
        .where('senderPetId', isEqualTo: senderPetId)
        .get();

    return snapshot.docs.map((doc) => doc['targetPetId'] as String).toList();
  }

  /// Get the list of all pet IDs that this pet has LIKED (for likes history)
  Future<List<String>> getLikedPetIds(String senderPetId) async {
    final snapshot = await _swipesCollection
        .where('senderPetId', isEqualTo: senderPetId)
        .where('isLike', isEqualTo: true)
        .get();

    final docs = List<QueryDocumentSnapshot>.from(snapshot.docs);
    docs.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>?;
      final bData = b.data() as Map<String, dynamic>?;
      final aTime = aData != null && aData.containsKey('createdAt') ? aData['createdAt'] as Timestamp? : null;
      final bTime = bData != null && bData.containsKey('createdAt') ? bData['createdAt'] as Timestamp? : null;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    return docs.map((doc) => doc['targetPetId'] as String).toList();
  }

  /// Get the list of all pet IDs that have LIKED this pet (received likes)
  Future<List<String>> getReceivedLikesPetIds(String targetPetId) async {
    final snapshot = await _swipesCollection
        .where('targetPetId', isEqualTo: targetPetId)
        .where('isLike', isEqualTo: true)
        .get();

    final docs = List<QueryDocumentSnapshot>.from(snapshot.docs);
    docs.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>?;
      final bData = b.data() as Map<String, dynamic>?;
      final aTime = aData != null && aData.containsKey('createdAt') ? aData['createdAt'] as Timestamp? : null;
      final bTime = bData != null && bData.containsKey('createdAt') ? bData['createdAt'] as Timestamp? : null;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });

    return docs.map((doc) => doc['senderPetId'] as String).toList();
  }
}
