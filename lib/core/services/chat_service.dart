import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/models/chat_model.dart';

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

  // Send message
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
}
