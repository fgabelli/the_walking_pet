import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/chat_service.dart';
import '../../../../shared/models/chat_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

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

  ChatController(this._chatService, this._ref) : super(ChatState());

  Future<String?> createChat(String otherUserId) async {
    state = ChatState(isLoading: true);
    try {
      final currentUser = _ref.read(authServiceProvider).currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final chatId = await _chatService.createChat(
        [currentUser.uid, otherUserId],
        currentUser.uid, // Initiator
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
    ref,
  );
});
