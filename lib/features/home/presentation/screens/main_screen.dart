import 'dart:io';
import 'package:flutter/material.dart';

import '../../../../core/constants/tutorial_keys.dart';
import '../../../../core/services/tutorial_service.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../map/presentation/screens/map_screen.dart';
import '../../../chat/presentation/screens/chat_list_screen.dart';
import '../../../social/presentation/screens/community_screen.dart';
import '../../../nextdoor/presentation/screens/pet_matcher_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/ad_readiness_provider.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../chat/presentation/providers/chat_provider.dart';

import '../../../../core/services/notification_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/purchase_service.dart';
import '../../../../core/services/device_health_service.dart';
import '../../../../core/services/analytics_service.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _selectedIndex = 0;

  /// Le tab vivono dentro un IndexedStack e non passano dal Navigator:
  /// l'observer in app.dart non le vedrebbe mai, vanno inviate a mano.
  /// L'ordine deve restare allineato a _screens.
  static const List<String> _nomiTab = [
    'community',
    'map',
    'pet_matcher',
    'chat_list',
    'profile',
  ];

  final List<Widget> _screens = [
    const CommunityScreen(),
    const MapScreen(),
    const PetMatcherScreen(),
    const ChatListScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    ref.read(activeTabProvider.notifier).state = index;
    AnalyticsService.schermataVista(_nomiTab[index]);
  }

  @override
  void initState() {
    super.initState();
    // Notification Service is already initialized in main.dart

    // La prima tab non passa da _onItemTapped: va registrata qui.
    AnalyticsService.schermataVista(_nomiTab[_selectedIndex]);

    // Request Health Permissions on Startup (iOS only — Health Connect disabled on Android)
    if (Platform.isIOS) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
         try {
           final healthService = ref.read(deviceHealthServiceProvider);
           final granted = await healthService.requestPermissions();
           debugPrint('Health Permissions requested: $granted');
         } catch (e) {
           debugPrint('Error requesting health permissions: $e');
         }
      });
    }
    
    // Sync Purchases Identity (Listen to Auth Changes)
    // This ensures we sync even if Auth takes a moment to initialize
    ref.listenManual(authServiceProvider, (previous, next) async {
       final user = next.currentUser;
       if (user != null) {
          debugPrint('AuthUser loaded: ${user.uid}, identifying in Purchases...');
          await ref.read(purchaseServiceProvider).identifyUser(user.uid);
       }
     });

    // Also check immediately in case it's already there
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authServiceProvider).currentUser;
      if (user != null) {
        ref.read(purchaseServiceProvider).identifyUser(user.uid);
      }
    });

    // Start onboarding tutorial if first launch
    _maybeStartTutorial();
  }

  Future<void> _maybeStartTutorial() async {
    final completed = await TutorialService.isOnboardingCompleted();
    if (!completed && mounted) {
      TutorialService.startOnboarding(
        context: context,
        tabSwitcher: (index) {
          if (mounted) {
            setState(() => _selectedIndex = index);
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(activeTabProvider);
    if (activeTab != _selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedIndex = activeTab;
          });
          // Cambio tab pilotato da fuori (notifica, deep link).
          AnalyticsService.schermataVista(_nomiTab[activeTab]);
        }
      });
    }

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            key: TutorialKeys.socialTabKey,
            icon: Consumer(
              builder: (context, ref, child) {
                final count = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
                return count > 0 
                  ? Badge(label: Text('$count'), child: const Icon(Icons.groups_outlined))
                  : const Icon(Icons.groups_outlined);
              },
            ),
            selectedIcon: Consumer(
              builder: (context, ref, child) {
                final count = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
                return count > 0 
                  ? Badge(label: Text('$count'), child: const Icon(Icons.groups))
                  : const Icon(Icons.groups);
              },
            ),
            label: 'Social',
          ),
          NavigationDestination(
            key: TutorialKeys.mapTabKey,
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map),
            label: 'Mappa',
          ),
          NavigationDestination(
            key: TutorialKeys.datingTabKey,
            icon: const Icon(Icons.favorite_border),
            selectedIcon: const Icon(Icons.favorite),
            label: 'Dating',
          ),
          NavigationDestination(
            key: TutorialKeys.chatTabKey,
            icon: Consumer(
              builder: (context, ref, child) {
                final count = ref.watch(unreadChatsCountProvider);
                return count > 0 
                  ? Badge(label: Text('$count'), child: const Icon(Icons.chat_bubble_outline))
                  : const Icon(Icons.chat_bubble_outline);
              },
            ),
            selectedIcon: Consumer(
              builder: (context, ref, child) {
                final count = ref.watch(unreadChatsCountProvider);
                return count > 0 
                  ? Badge(label: Text('$count'), child: const Icon(Icons.chat_bubble))
                  : const Icon(Icons.chat_bubble);
              },
            ),
            label: 'Chat',
          ),
          NavigationDestination(
            key: TutorialKeys.profileTabKey,
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: 'Profilo',
          ),
        ],
      ),
    );
  }
}
