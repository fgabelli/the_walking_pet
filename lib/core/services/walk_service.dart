import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/models/walk_model.dart';

class WalkService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'walks';

  // Create walk
  Future<String> createWalk(WalkModel walk) async {
    try {
      final docRef = await _firestore.collection(_collection).add(walk.toFirestore());
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  // Get upcoming walks stream
  Stream<List<WalkModel>> getUpcomingWalks() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          final List<WalkModel> activeWalks = [];

          for (final doc in snapshot.docs) {
            final walk = WalkModel.fromFirestore(doc);
            
            // Calculate end time
            final endTime = walk.date.add(Duration(minutes: walk.duration));
            
            if (endTime.isAfter(now)) {
              // Not expired yet
              if (walk.status == WalkStatus.upcoming) {
                 activeWalks.add(walk);
              }
            } else {
              // Expired, check recurrence
              if (walk.recurrence != Recurrence.none && walk.status != WalkStatus.cancelled) {
                 // Project date
                 DateTime nextDate = walk.date;
                 while (nextDate.add(Duration(minutes: walk.duration)).isBefore(now)) {
                    if (walk.recurrence == Recurrence.daily) {
                      nextDate = nextDate.add(const Duration(days: 1));
                    } else if (walk.recurrence == Recurrence.weekly) {
                      nextDate = nextDate.add(const Duration(days: 7));
                    } else if (walk.recurrence == Recurrence.custom && walk.recurrenceDays.isNotEmpty) {
                      // Move to next allowed day
                      do {
                        nextDate = nextDate.add(const Duration(days: 1));
                      } while (!walk.recurrenceDays.contains(nextDate.weekday));
                    } else {
                       // Fallback if custom has no days or unknown recurrence type to prevent infinite loop
                       // Just break or treat as non-recurring? 
                       // Loop condition might prevent breaking if we don't advance.
                       // Force advance 1 day to be safe or break.
                       nextDate = nextDate.add(const Duration(days: 1));
                    }
                 }
                 // Return virtual copy with new date
                 activeWalks.add(walk.copyWith(date: nextDate));
              }
            }
          }
          
          // Sort by date
          activeWalks.sort((a, b) => a.date.compareTo(b.date));
          
          return activeWalks;
        });
  }

  // Get walk by ID
  Future<WalkModel?> getWalkById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        return WalkModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Join walk
  Future<void> joinWalk(String walkId, String userId) async {
    try {
      await _firestore.collection(_collection).doc(walkId).update({
        'participants': FieldValue.arrayUnion([userId]),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Leave walk
  Future<void> leaveWalk(String walkId, String userId) async {
    try {
      await _firestore.collection(_collection).doc(walkId).update({
        'participants': FieldValue.arrayRemove([userId]),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Cancel walk
  Future<void> cancelWalk(String walkId) async {
    try {
      await _firestore.collection(_collection).doc(walkId).update({
        'status': WalkStatus.cancelled.name,
      });
    } catch (e) {
      rethrow;
    }
  }

  // Update walk
  Future<void> updateWalk(WalkModel walk) async {
    try {
      await _firestore.collection(_collection).doc(walk.id).update(walk.toFirestore());
    } catch (e) {
      rethrow;
    }
  }

  // Delete walk
  Future<void> deleteWalk(String walkId) async {
    try {
      await _firestore.collection(_collection).doc(walkId).delete();
    } catch (e) {
      rethrow;
    }
  }
}
