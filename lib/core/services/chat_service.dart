import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/models/chat_model.dart';
import 'analytics_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'chats';

  // Create or get existing chat
  Future<String> createChat(List<String> userIds, String initiatorId, {ChatStatus initialStatus = ChatStatus.pending}) async {
    try {
      userIds.sort();
      final chatId = userIds.join('_');
      
      final doc = await _firestore.collection(_collection).doc(chatId).get();
      
      if (!doc.exists) {
        await _firestore.collection(_collection).doc(chatId).set({
          'participants': userIds,
          'updatedAt': FieldValue.serverTimestamp(),
          'status': initialStatus.name,
          'initiatorId': initiatorId,
        });
        // Solo per le conversazioni nuove, non a ogni riapertura.
        await AnalyticsService.chatAvviata();
      }
      
      return chatId;
    } catch (e) {
      rethrow;
    }
  }

  // Accept chat
  Future<void> acceptChat(String chatId) async {
    try {
      await _firestore.collection(_collection).doc(chatId).update({
        'status': ChatStatus.accepted.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Decline chat
  Future<void> declineChat(String chatId) async {
    try {
      await _firestore.collection(_collection).doc(chatId).update({
        'status': ChatStatus.declined.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Get chats for user
  Stream<List<ChatModel>> getChats(String userId) {
    return _firestore
        .collection(_collection)
        .where('participants', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => ChatModel.fromFirestore(doc)).toList());
  }

  // Send message (with optional reply)
  Future<void> sendMessage(String chatId, MessageModel message) async {
    try {
      final batch = _firestore.batch();
      
      // Add message to subcollection
      final messageRef = _firestore
          .collection(_collection)
          .doc(chatId)
          .collection('messages')
          .doc(); // Generate ID
          
      final messageWithId = MessageModel(
        id: messageRef.id,
        senderId: message.senderId,
        text: message.text,
        timestamp: message.timestamp,
        type: message.type,
        isRead: false,
        replyToId: message.replyToId,
        replyToText: message.replyToText,
        replyToSenderId: message.replyToSenderId,
        metadata: message.metadata,
      );

      batch.set(messageRef, messageWithId.toMap());

      // Update chat last message
      final chatRef = _firestore.collection(_collection).doc(chatId);
      batch.update(chatRef, {
        'lastMessage': messageWithId.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  // Get messages stream
  Stream<List<MessageModel>> getMessages(String chatId) {
    return _firestore
        .collection(_collection)
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => MessageModel.fromFirestore(doc)).toList());
  }

  // Get single chat stream
  Stream<ChatModel> getChatStream(String chatId) {
    return _firestore
        .collection(_collection)
        .doc(chatId)
        .snapshots()
        .map((doc) => ChatModel.fromFirestore(doc));
  }

  // Delete chat and all its messages
  Future<void> deleteChat(String chatId) async {
    try {
      final messagesSnapshot = await _firestore
          .collection(_collection)
          .doc(chatId)
          .collection('messages')
          .get();

      final batch = _firestore.batch();
      for (final doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_firestore.collection(_collection).doc(chatId));
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  // ─── NEW: Toggle reaction on a message ───
  Future<void> toggleReaction(String chatId, String messageId, String userId, String emoji) async {
    final ref = _firestore
        .collection(_collection)
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    final doc = await ref.get();
    if (!doc.exists) return;

    final reactions = Map<String, String>.from(
      (doc.data()?['reactions'] as Map<String, dynamic>?) ?? {},
    );

    // Toggle: if same emoji → remove, if different or new → set
    if (reactions[userId] == emoji) {
      reactions.remove(userId);
    } else {
      reactions[userId] = emoji;
    }

    await ref.update({'reactions': reactions});
  }

  // ─── NEW: Edit message text ───
  Future<void> editMessage(String chatId, String messageId, String newText) async {
    await _firestore
        .collection(_collection)
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'text': newText,
      'isEdited': true,
    });
  }

  // ─── NEW: Soft-delete message ───
  Future<void> deleteMessage(String chatId, String messageId) async {
    await _firestore
        .collection(_collection)
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({
      'isDeleted': true,
      'text': '',
      'reactions': {},
    });
  }

  // Mark all messages in a chat as read (except those sent by current user)
  Future<void> markMessagesAsRead(String chatId, String currentUserId) async {
    try {
      final messagesRef = _firestore
          .collection(_collection)
          .doc(chatId)
          .collection('messages');
          
      final unreadSnapshot = await messagesRef
          .where('senderId', isNotEqualTo: currentUserId)
          .get();
          
      final batch = _firestore.batch();
      bool hasUpdates = false;
      
      for (final doc in unreadSnapshot.docs) {
        final data = doc.data();
        if (data['isRead'] != true) {
          batch.update(doc.reference, {'isRead': true});
          hasUpdates = true;
        }
      }
      
      final chatRef = _firestore.collection(_collection).doc(chatId);
      final chatDoc = await chatRef.get();
      if (chatDoc.exists) {
        final chatData = chatDoc.data();
        final lastMessageMap = chatData?['lastMessage'] as Map<String, dynamic>?;
        if (lastMessageMap != null && 
            lastMessageMap['senderId'] != currentUserId && 
            lastMessageMap['isRead'] != true) {
          lastMessageMap['isRead'] = true;
          batch.update(chatRef, {'lastMessage': lastMessageMap});
          hasUpdates = true;
        }
      }
      
      if (hasUpdates) {
        await batch.commit();
        print("Marked messages as read in chat $chatId");
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }
}
