import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the AdMob SDK has been fully initialized (consent + MobileAds.instance.initialize()).
/// UnifiedAdCard widgets MUST wait for this to be `true` before calling load().
final adMobReadyProvider = StateProvider<bool>((ref) => false);

/// The currently active tab index in MainScreen (0-4).
/// Used by UnifiedAdCard to defer ad loading until the owning tab is visible.
final activeTabProvider = StateProvider<int>((ref) => 0);

/// The currently active sub-tab index in CommunityScreen (0-2).
/// 0: Per te (Feed), 1: Reels, 2: Bacheca.
final communityTabProvider = StateProvider<int>((ref) => 0);

/// Global mute state for reels. Starts as true (muted by default).
final reelsMutedProvider = StateProvider<bool>((ref) => true);
