import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/chat_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../shared/models/chat_model.dart';
import '../../../../shared/models/dog_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/user_service.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

/// Chat Service Provider
final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

/// User Chats Stream Provider
final userChatsProvider = StreamProvider<List<ChatModel>>((ref) {
  final user = ref.watch(authServiceProvider).currentUser;
  if (user == null) return Stream.value([]);
  return ref.watch(chatServiceProvider).getChats(user.uid);
});

/// Chat Messages Stream Provider (Family)
final chatMessagesProvider = StreamProvider.family<List<MessageModel>, String>((ref, chatId) {
  return ref.watch(chatServiceProvider).getMessages(chatId);
});

/// Chat Stream Provider (Family)
final chatStreamProvider = StreamProvider.family<ChatModel, String>((ref, chatId) {
  return ref.watch(chatServiceProvider).getChatStream(chatId);
});

/// Chat Controller State
class ChatState {
  final bool isLoading;
  final String? error;

  ChatState({this.isLoading = false, this.error});
}

/// Chat Controller
class ChatController extends StateNotifier<ChatState> {
  final ChatService _chatService;
  final Ref _ref;
  final UserService _userService;
  
  ChatController(this._chatService, this._userService, this._ref) : super(ChatState());

  Future<String?> createChat(String otherUserId, {ChatStatus initialStatus = ChatStatus.pending}) async {
    state = ChatState(isLoading: true);
    try {
      final currentUser = _ref.read(authServiceProvider).currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final myProfile = await _userService.getUserById(currentUser.uid);
      if (myProfile != null && myProfile.blockedUsers.contains(otherUserId)) {
        throw Exception('Non puoi creare una chat con un utente bloccato');
      }
      final otherProfile = await _userService.getUserById(otherUserId);
      if (otherProfile != null && otherProfile.blockedUsers.contains(currentUser.uid)) {
         throw Exception('Non puoi creare una chat con questo utente');
      }

      final chatId = await _chatService.createChat(
        [currentUser.uid, otherUserId],
        currentUser.uid,
        initialStatus: initialStatus,
      );
      state = ChatState(isLoading: false);
      return chatId;
    } catch (e) {
      state = ChatState(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<void> sendMessage(String chatId, String text, {MessageModel? replyTo}) async {
    if (text.trim().isEmpty) return;
    
    try {
      final currentUser = _ref.read(authServiceProvider).currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final message = MessageModel(
        id: '',
        senderId: currentUser.uid,
        text: text.trim(),
        timestamp: DateTime.now(),
        replyToId: replyTo?.id,
        replyToText: replyTo != null
            ? (replyTo.text.length > 80 ? '${replyTo.text.substring(0, 80)}…' : replyTo.text)
            : null,
        replyToSenderId: replyTo?.senderId,
      );

      await _chatService.sendMessage(chatId, message);
    } catch (e) {
      state = ChatState(error: e.toString());
    }
  }

  Future<void> acceptChat(String chatId) async {
    state = ChatState(isLoading: true);
    try {
      await _chatService.acceptChat(chatId);
      state = ChatState(isLoading: false);
    } catch (e) {
      state = ChatState(isLoading: false, error: e.toString());
    }
  }

  Future<void> declineChat(String chatId) async {
    state = ChatState(isLoading: true);
    try {
      await _chatService.declineChat(chatId);
      state = ChatState(isLoading: false);
    } catch (e) {
      state = ChatState(isLoading: false, error: e.toString());
    }
  }

  Future<void> deleteChat(String chatId) async {
    state = ChatState(isLoading: true);
    try {
      await _chatService.deleteChat(chatId);
      state = ChatState(isLoading: false);
    } catch (e) {
      state = ChatState(isLoading: false, error: e.toString());
    }
  }

  Future<void> blockUserFromChat(String otherUserId) async {
    state = ChatState(isLoading: true);
    try {
      final currentUser = _ref.read(authServiceProvider).currentUser;
      if (currentUser == null) throw Exception('User not authenticated');
      await _userService.blockUser(currentUser.uid, otherUserId);
      state = ChatState(isLoading: false);
    } catch (e) {
      state = ChatState(isLoading: false, error: e.toString());
    }
  }

  Future<void> reportUserFromChat({
    required String otherUserId,
    required String reason,
    String? description,
  }) async {
    state = ChatState(isLoading: true);
    try {
      final currentUser = _ref.read(authServiceProvider).currentUser;
      if (currentUser == null) throw Exception('User not authenticated');
      await _userService.reportUser(
        reporterId: currentUser.uid,
        reportedUserId: otherUserId,
        reason: reason,
        description: description,
      );
      state = ChatState(isLoading: false);
    } catch (e) {
      state = ChatState(isLoading: false, error: e.toString());
    }
  }

  // ─── NEW: Toggle reaction ───
  Future<void> toggleReaction(String chatId, String messageId, String emoji) async {
    try {
      final currentUser = _ref.read(authServiceProvider).currentUser;
      if (currentUser == null) return;
      await _chatService.toggleReaction(chatId, messageId, currentUser.uid, emoji);
    } catch (e) {
      state = ChatState(error: e.toString());
    }
  }

  // ─── NEW: Edit message ───
  Future<void> editMessage(String chatId, String messageId, String newText) async {
    if (newText.trim().isEmpty) return;
    try {
      await _chatService.editMessage(chatId, messageId, newText.trim());
    } catch (e) {
      state = ChatState(error: e.toString());
    }
  }

  // ─── NEW: Delete message (soft) ───
  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      await _chatService.deleteMessage(chatId, messageId);
    } catch (e) {
      state = ChatState(error: e.toString());
    }
  }

  // ─── NEW: Send image message ───
  Future<void> sendImage(String chatId, File imageFile) async {
    state = ChatState(isLoading: true);
    try {
      final currentUser = _ref.read(authServiceProvider).currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Upload to Firebase Storage
      final storageService = _ref.read(storageServiceProvider);
      final imageUrl = await storageService.uploadChatImage(chatId, imageFile);

      final message = MessageModel(
        id: '',
        senderId: currentUser.uid,
        text: '📷 Foto',
        timestamp: DateTime.now(),
        type: MessageType.image,
        metadata: {'imageUrl': imageUrl},
      );

      await _chatService.sendMessage(chatId, message);
      state = ChatState(isLoading: false);
    } catch (e) {
      state = ChatState(isLoading: false, error: e.toString());
    }
  }

  // ─── NEW: Send location message ───
  Future<void> sendLocation(String chatId, double latitude, double longitude, String? address) async {
    try {
      final currentUser = _ref.read(authServiceProvider).currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final message = MessageModel(
        id: '',
        senderId: currentUser.uid,
        text: '📍 ${address ?? 'Posizione condivisa'}',
        timestamp: DateTime.now(),
        type: MessageType.location,
        metadata: {
          'latitude': latitude,
          'longitude': longitude,
          if (address != null) 'address': address,
        },
      );

      await _chatService.sendMessage(chatId, message);
    } catch (e) {
      state = ChatState(error: e.toString());
    }
  }

  // ─── NEW: Send pet card message ───
  Future<void> sendPetCard(String chatId, DogModel dog) async {
    try {
      final currentUser = _ref.read(authServiceProvider).currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final message = MessageModel(
        id: '',
        senderId: currentUser.uid,
        text: '🐕 ${dog.name}',
        timestamp: DateTime.now(),
        type: MessageType.petCard,
        metadata: {
          'petId': dog.id,
          'petName': dog.name,
          'petBreed': dog.breed,
          'petAge': dog.age,
          'petGender': dog.gender.name,
          if (dog.photoUrl != null) 'petPhotoUrl': dog.photoUrl!,
        },
      );

      await _chatService.sendMessage(chatId, message);
    } catch (e) {
      state = ChatState(error: e.toString());
    }
  }

  // ─── NEW: Send walk invite message ───
  Future<void> sendWalkInvite(String chatId, {
    required String locationName,
    required double latitude,
    required double longitude,
    required DateTime dateTime,
    String? note,
  }) async {
    try {
      final currentUser = _ref.read(authServiceProvider).currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final message = MessageModel(
        id: '',
        senderId: currentUser.uid,
        text: '🚶 Passeggiata: $locationName',
        timestamp: DateTime.now(),
        type: MessageType.walkInvite,
        metadata: {
          'locationName': locationName,
          'latitude': latitude,
          'longitude': longitude,
          'dateTime': dateTime.toIso8601String(),
          if (note != null) 'note': note,
        },
      );

      await _chatService.sendMessage(chatId, message);
    } catch (e) {
      state = ChatState(error: e.toString());
    }
  }
}

/// Chat Controller Provider
final chatControllerProvider = StateNotifierProvider<ChatController, ChatState>((ref) {
  return ChatController(
    ref.watch(chatServiceProvider),
    ref.watch(userServiceProvider),
    ref,
  );
});

/// Unread Chats Count Provider
final unreadChatsCountProvider = Provider<int>((ref) {
  final chatsAsync = ref.watch(userChatsProvider);
  final currentUser = ref.watch(authServiceProvider).currentUser;
  if (currentUser == null) return 0;
  
  return chatsAsync.when(
    data: (chats) {
      return chats.where((chat) {
        return chat.lastMessage != null &&
            !chat.lastMessage!.isRead &&
            chat.lastMessage!.senderId != currentUser.uid;
      }).length;
    },
    loading: () => 0,
    error: (_, __) => 0,
  );
});

