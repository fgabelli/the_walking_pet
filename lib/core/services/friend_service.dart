import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/models/user_model.dart';
import 'auth_service.dart';

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Send Friend Request
  Future<void> sendFriendRequest(String toUserId) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) throw Exception('Utente non autenticato');

    // Add to target user's friendRequests
    await _firestore.collection('users').doc(toUserId).update({
      'friendRequests': FieldValue.arrayUnion([currentUser.uid]),
    });
  }

  // Accept Friend Request
  Future<void> acceptFriendRequest(String fromUserId) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) throw Exception('Utente non autenticato');

    final batch = _firestore.batch();

    // 1. Add to current user's friends and remove from requests
    final currentUserRef = _firestore.collection('users').doc(currentUser.uid);
    batch.update(currentUserRef, {
      'friends': FieldValue.arrayUnion([fromUserId]),
      'friendRequests': FieldValue.arrayRemove([fromUserId]),
    });

    // 2. Add current user to sender's friends
    final senderRef = _firestore.collection('users').doc(fromUserId);
    batch.update(senderRef, {
      'friends': FieldValue.arrayUnion([currentUser.uid]),
    });

    await batch.commit();
  }

  // Decline Friend Request
  Future<void> declineFriendRequest(String fromUserId) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) throw Exception('Utente non autenticato');

    await _firestore.collection('users').doc(currentUser.uid).update({
      'friendRequests': FieldValue.arrayRemove([fromUserId]),
    });
  }

  // Remove Friend
  Future<void> removeFriend(String friendId) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) throw Exception('Utente non autenticato');

    final batch = _firestore.batch();

    // Remove from current user
    final currentUserRef = _firestore.collection('users').doc(currentUser.uid);
    batch.update(currentUserRef, {
      'friends': FieldValue.arrayRemove([friendId]),
    });

    // Remove from friend
    final friendRef = _firestore.collection('users').doc(friendId);
    batch.update(friendRef, {
      'friends': FieldValue.arrayRemove([currentUser.uid]),
    });

    await batch.commit();
  }

  // Update Location Privacy
  Future<void> updateLocationPrivacy({
    required LocationPrivacy privacy,
    List<String>? whitelist,
  }) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) throw Exception('Utente non autenticato');

    final Map<String, dynamic> data = {
      'locationPrivacy': privacy.name,
    };

    if (whitelist != null) {
      data['locationWhitelist'] = whitelist;
    }

    await _firestore.collection('users').doc(currentUser.uid).update(data);
  }
}
