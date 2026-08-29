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
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
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
  // --- New fields ---
  final Map<String, String> reactions; // userId -> emoji
  final String? replyToId;            // ID of the message being replied to
  final String? replyToText;          // Cached text preview of the replied message
  final String? replyToSenderId;      // Sender of the replied message
  final bool isEdited;
  final bool isDeleted;
  // --- Rich content metadata ---
  final Map<String, dynamic> metadata; // For image URL, location, pet card, walk invite

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.type = MessageType.text,
    this.isRead = false,
    this.reactions = const {},
    this.replyToId,
    this.replyToText,
    this.replyToSenderId,
    this.isEdited = false,
    this.isDeleted = false,
    this.metadata = const {},
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      type: MessageType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => MessageType.text,
      ),
      isRead: data['isRead'] ?? false,
      reactions: Map<String, String>.from(data['reactions'] ?? {}),
      replyToId: data['replyToId'],
      replyToText: data['replyToText'],
      replyToSenderId: data['replyToSenderId'],
      isEdited: data['isEdited'] ?? false,
      isDeleted: data['isDeleted'] ?? false,
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      type: MessageType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MessageType.text,
      ),
      isRead: map['isRead'] ?? false,
      reactions: Map<String, String>.from(map['reactions'] ?? {}),
      replyToId: map['replyToId'],
      replyToText: map['replyToText'],
      replyToSenderId: map['replyToSenderId'],
      isEdited: map['isEdited'] ?? false,
      isDeleted: map['isDeleted'] ?? false,
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
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
      'reactions': reactions,
      if (replyToId != null) 'replyToId': replyToId,
      if (replyToText != null) 'replyToText': replyToText,
      if (replyToSenderId != null) 'replyToSenderId': replyToSenderId,
      'isEdited': isEdited,
      'isDeleted': isDeleted,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }

  MessageModel copyWith({
    String? id,
    String? senderId,
    String? text,
    DateTime? timestamp,
    MessageType? type,
    bool? isRead,
    Map<String, String>? reactions,
    String? replyToId,
    String? replyToText,
    String? replyToSenderId,
    bool? isEdited,
    bool? isDeleted,
    Map<String, dynamic>? metadata,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      reactions: reactions ?? this.reactions,
      replyToId: replyToId ?? this.replyToId,
      replyToText: replyToText ?? this.replyToText,
      replyToSenderId: replyToSenderId ?? this.replyToSenderId,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      metadata: metadata ?? this.metadata,
    );
  }
}

enum MessageType {
  text,
  image,
  location,
  petCard,
  walkInvite,
}
