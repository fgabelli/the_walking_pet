import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatStatus {
  pending,
  accepted,
  declined,
}

/// Chat Model
class ChatModel {
  final String id;
  final List<String> participants;
  final MessageModel? lastMessage;
  final DateTime updatedAt;
  final Map<String, dynamic>? participantData; // Optional: Cache user data
  final ChatStatus status;
  final String? initiatorId;

  ChatModel({
    required this.id,
    required this.participants,
    this.lastMessage,
    required this.updatedAt,
    this.participantData,
    this.status = ChatStatus.accepted, // Default for migration/backward compatibility
    this.initiatorId,
  });

  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatModel(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'] != null
          ? MessageModel.fromMap(data['lastMessage'] as Map<String, dynamic>)
          : null,
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      participantData: data['participantData'] as Map<String, dynamic>?,
      status: ChatStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'accepted'),
        orElse: () => ChatStatus.accepted,
      ),
      initiatorId: data['initiatorId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'participants': participants,
      'lastMessage': lastMessage?.toMap(),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'participantData': participantData,
      'status': status.name,
      'initiatorId': initiatorId,
    };
  }
}

/// Message Model
class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final MessageType type;
  final bool isRead;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.type = MessageType.text,
    this.isRead = false,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      type: MessageType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => MessageType.text,
      ),
      isRead: data['isRead'] ?? false,
    );
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      type: MessageType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MessageType.text,
      ),
      isRead: map['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type.name,
      'isRead': isRead,
    };
  }
}

enum MessageType {
  text,
  image,
  location,
}
