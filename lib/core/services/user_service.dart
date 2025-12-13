import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/models/user_model.dart';

/// User service for Firestore operations
class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'users';

  // Get user by ID
  Future<UserModel?> getUserById(String uid) async {
    try {
      final doc = await _firestore.collection(_collection).doc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Get user stream
  Stream<UserModel?> getUserStream(String uid) {
    return _firestore
        .collection(_collection)
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  // Create user
  Future<void> createUser(UserModel user) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(user.uid)
          .set(user.toFirestore());
    } catch (e) {
      rethrow;
    }
  }

  // Update user
  Future<void> updateUser(UserModel user) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(user.uid)
          .update(user.toFirestore());
    } catch (e) {
      rethrow;
    }
  }

  // Update specific fields
  Future<void> updateUserFields(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(_collection).doc(uid).update(data);
    } catch (e) {
      rethrow;
    }
  }

  // Delete user
  Future<void> deleteUser(String uid) async {
    try {
      await _firestore.collection(_collection).doc(uid).delete();
    } catch (e) {
      rethrow;
    }
  }

  // Get users in zone
  Future<List<UserModel>> getUsersInZone(String zone) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('zone', isEqualTo: zone)
          .get();
      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      rethrow;
    }
  }

  // Search users by name
  Future<List<UserModel>> searchUsersByName(String query) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('firstName', isGreaterThanOrEqualTo: query)
          .where('firstName', isLessThanOrEqualTo: '$query\uf8ff')
          .get();
      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      rethrow;
    }
  }

  // Update FCM token
  Future<void> updateFcmToken(String uid, String token) async {
    try {
      await _firestore.collection(_collection).doc(uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Remove FCM token
  Future<void> removeFcmToken(String uid, String token) async {
    try {
      await _firestore.collection(_collection).doc(uid).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> rejectFriendRequest(String currentUserId, String requesterId) async {
    final batch = _firestore.batch();
    
    // Remove from current user's requests
    final currentUserRef = _firestore.collection(_collection).doc(currentUserId);
    batch.update(currentUserRef, {
      'friendRequests': FieldValue.arrayRemove([requesterId]),
    });
    
    await batch.commit();
  }

  // Follow System (For Business Profiles)
  Future<void> followUser(String currentUserId, String targetUserId) async {
    final batch = _firestore.batch();
    
    // Add target to current user's 'following' list
    final currentUserRef = _firestore.collection(_collection).doc(currentUserId);
    batch.update(currentUserRef, {
      'following': FieldValue.arrayUnion([targetUserId]),
    });
    
    // Add current user to target's 'followers' list
    final targetUserRef = _firestore.collection(_collection).doc(targetUserId);
    batch.update(targetUserRef, {
      'followers': FieldValue.arrayUnion([currentUserId]),
    });
    
    await batch.commit();
  }

  Future<void> unfollowUser(String currentUserId, String targetUserId) async {
    final batch = _firestore.batch();
    
    // Remove target from current user's 'following' list
    final currentUserRef = _firestore.collection(_collection).doc(currentUserId);
    batch.update(currentUserRef, {
      'following': FieldValue.arrayRemove([targetUserId]),
    });
    
    // Remove current user from target's 'followers' list
    final targetUserRef = _firestore.collection(_collection).doc(targetUserId);
    batch.update(targetUserRef, {
      'followers': FieldValue.arrayRemove([currentUserId]),
    });
    
    await batch.commit();
  }
  
  // Block user
  Future<void> blockUser(String currentUserId, String blockedUserId) async {
    try {
      await _firestore.collection(_collection).doc(currentUserId).update({
        'blockedUsers': FieldValue.arrayUnion([blockedUserId]),
      });
      // Optionally remove from friends if blocked
      await _firestore.collection(_collection).doc(currentUserId).update({
        'friends': FieldValue.arrayRemove([blockedUserId]),
      });
      // And remove self from their friends
      await _firestore.collection(_collection).doc(blockedUserId).update({
        'friends': FieldValue.arrayRemove([currentUserId]),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Unblock user
  Future<void> unblockUser(String currentUserId, String blockedUserId) async {
    try {
      await _firestore.collection(_collection).doc(currentUserId).update({
        'blockedUsers': FieldValue.arrayRemove([blockedUserId]),
      });
    } catch (e) {
      rethrow;
    }
  }
}
