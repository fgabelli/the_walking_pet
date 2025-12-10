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
        .map((snapshot) => snapshot.docs
            .map((doc) => WalkModel.fromFirestore(doc))
            .where((walk) => walk.status == WalkStatus.upcoming)
            .toList());
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
