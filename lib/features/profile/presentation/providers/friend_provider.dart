import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/friend_service.dart';
import '../../../../shared/models/user_model.dart';

final friendServiceProvider = Provider<FriendService>((ref) {
  return FriendService();
});

class FriendController extends StateNotifier<AsyncValue<void>> {
  final FriendService _friendService;

  FriendController(this._friendService) : super(const AsyncValue.data(null));

  Future<void> sendFriendRequest(String toUserId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _friendService.sendFriendRequest(toUserId));
  }

  Future<void> acceptFriendRequest(String fromUserId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _friendService.acceptFriendRequest(fromUserId));
  }

  Future<void> declineFriendRequest(String fromUserId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _friendService.declineFriendRequest(fromUserId));
  }

  Future<void> removeFriend(String friendId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _friendService.removeFriend(friendId));
  }

  Future<void> updateLocationPrivacy({
    required LocationPrivacy privacy,
    List<String>? whitelist,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _friendService.updateLocationPrivacy(
      privacy: privacy,
      whitelist: whitelist,
    ));
  }
}

final friendControllerProvider = StateNotifierProvider<FriendController, AsyncValue<void>>((ref) {
  return FriendController(ref.watch(friendServiceProvider));
});
