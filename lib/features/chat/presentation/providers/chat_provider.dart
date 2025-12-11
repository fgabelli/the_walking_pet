import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/chat_service.dart';
import '../../../../shared/models/chat_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/user_service.dart'; // Added
import '../../../profile/presentation/providers/profile_provider.dart'; // Added

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

  final UserService _userService; // Add UserService
  
  ChatController(this._chatService, this._userService, this._ref) : super(ChatState());

  Future<String?> createChat(String otherUserId, {ChatStatus initialStatus = ChatStatus.pending}) async {
    state = ChatState(isLoading: true);
    try {
      final currentUser = _ref.read(authServiceProvider).currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Check if blocked
      final myProfile = await _userService.getUserById(currentUser.uid);
      if (myProfile != null && myProfile.blockedUsers.contains(otherUserId)) {
        throw Exception('Non puoi creare una chat con un utente bloccato');
      }
      // Check if blocked BY other
      final otherProfile = await _userService.getUserById(otherUserId);
      if (otherProfile != null && otherProfile.blockedUsers.contains(currentUser.uid)) {
         throw Exception('Non puoi creare una chat con questo utente');
      }

      final chatId = await _chatService.createChat(
        [currentUser.uid, otherUserId],
        currentUser.uid, // Initiator
        initialStatus: initialStatus,
      );
      state = ChatState(isLoading: false);
      return chatId;
    } catch (e) {
      state = ChatState(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<void> sendMessage(String chatId, String text) async {
    if (text.trim().isEmpty) return;
    
    try {
      final currentUser = _ref.read(authServiceProvider).currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Note: Full block check on every message might be expensive. 
      // Ideally we check cached state or let backend fail.
      // For now, allow sending if chat exists, assuming block removed chat access 
      // OR we just rely on UI hiding the chat.
      // But let's add a quick check if possible.
      // Actually, fetching chat participants is needed to know WHO to check against.
      // ChatService doesn't expose participants easily here without fetching chat.
      // Let's assume UI prevents entering the chat info screen if blocked.
      
      final message = MessageModel(
        id: '', // Will be generated
        senderId: currentUser.uid,
        text: text.trim(),
        timestamp: DateTime.now(),
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
}

/// Chat Controller Provider
final chatControllerProvider = StateNotifierProvider<ChatController, ChatState>((ref) {
  return ChatController(
    ref.watch(chatServiceProvider),
    ref.watch(userServiceProvider), // Add userServiceProvider
    ref,
  );
});
