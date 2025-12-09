import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/walk_service.dart';
import '../../../../shared/models/walk_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/chat_service.dart'; // Needed to create chat for walk

/// Walk Service Provider
final walkServiceProvider = Provider<WalkService>((ref) {
  return WalkService();
});

/// Upcoming Walks Stream Provider
final upcomingWalksProvider = StreamProvider<List<WalkModel>>((ref) {
  return ref.watch(walkServiceProvider).getUpcomingWalks();
});

/// Walk Controller State
class WalkState {
  final bool isLoading;
  final String? error;

  WalkState({this.isLoading = false, this.error});
}

/// Walk Controller
class WalkController extends StateNotifier<WalkState> {
  final WalkService _walkService;
  final ChatService _chatService; // To create group chat for walk
  final Ref _ref;

  WalkController(this._walkService, this._chatService, this._ref) : super(WalkState());

  Future<void> createWalk({
    required String title,
    required String description,
    required DateTime date,
    required int duration,
    required MeetingPoint meetingPoint,
    int? maxParticipants,
  }) async {
    state = WalkState(isLoading: true);
    try {
      final currentUser = _ref.read(authServiceProvider).currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // 1. Create a chat for the walk (optional, or create it when first person joins?)
      // Let's create it now so we have the ID.
      // For group chats, we might need a different createChat method or just use a list.
      // Since my ChatService.createChat takes a list of userIds and checks for existing 1-on-1...
      // I might need to update ChatService to support group chats or just create a doc directly here.
      // For simplicity, let's assume we create a chat doc with just the creator for now.
      // But wait, ChatService.createChat logic was specific to 1-on-1.
      // I should probably add createGroupChat to ChatService or handle it here.
      // Let's skip chat creation for a second and just use a placeholder or empty string, 
      // OR better: Update ChatService to handle group chats.
      
      // Assuming we just generate a UUID for chat or let Firestore generate it.
      // Let's just create the walk first.
      
      final newWalk = WalkModel(
        id: '', // Will be set by Firestore
        creatorId: currentUser.uid,
        title: title,
        description: description,
        date: date,
        duration: duration,
        meetingPoint: meetingPoint,
        participants: [currentUser.uid], // Creator is first participant
        maxParticipants: maxParticipants,
        chatId: '', // TODO: Implement group chat creation
        status: WalkStatus.upcoming,
        createdAt: DateTime.now(),
      );

      await _walkService.createWalk(newWalk);
      state = WalkState(isLoading: false);
    } catch (e) {
      state = WalkState(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateWalk(WalkModel walk) async {
    state = WalkState(isLoading: true);
    try {
      await _walkService.updateWalk(walk);
      state = WalkState(isLoading: false);
    } catch (e) {
      state = WalkState(isLoading: false, error: e.toString());
    }
  }

  Future<void> deleteWalk(String walkId) async {
    state = WalkState(isLoading: true);
    try {
      await _walkService.deleteWalk(walkId);
      state = WalkState(isLoading: false);
    } catch (e) {
      state = WalkState(isLoading: false, error: e.toString());
    }
  }

  Future<void> joinWalk(String walkId) async {
    state = WalkState(isLoading: true);
    try {
      final currentUser = _ref.read(authServiceProvider).currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      await _walkService.joinWalk(walkId, currentUser.uid);
      state = WalkState(isLoading: false);
    } catch (e) {
      state = WalkState(isLoading: false, error: e.toString());
    }
  }

  Future<void> leaveWalk(String walkId) async {
    state = WalkState(isLoading: true);
    try {
      final currentUser = _ref.read(authServiceProvider).currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      await _walkService.leaveWalk(walkId, currentUser.uid);
      state = WalkState(isLoading: false);
    } catch (e) {
      state = WalkState(isLoading: false, error: e.toString());
    }
  }
}

/// Walk Controller Provider
final walkControllerProvider = StateNotifierProvider<WalkController, WalkState>((ref) {
  // We need ChatService here too if we want to create chats
  // Importing ChatService directly or via provider
  // Since ChatService is in core, we can just instantiate it or use a provider if we made one.
  // We made chatServiceProvider in chat_provider.dart. 
  // But importing chat_provider.dart might cause circular dependency if chat_provider imports something else.
  // Let's just instantiate ChatService for now or define a provider for it in core if needed.
  // Actually, I can just use `ref.watch(walkServiceProvider)` and `ChatService()`.
  
  return WalkController(
    ref.watch(walkServiceProvider),
    ChatService(), // Direct instantiation for now to avoid circular deps with chat feature
    ref,
  );
});
