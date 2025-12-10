import 'package:flutter/material.dart';

import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../map/presentation/screens/map_screen.dart';
import '../../../walks/presentation/screens/walks_list_screen.dart';
import '../../../chat/presentation/screens/chat_list_screen.dart';
import '../../../nextdoor/presentation/screens/nextdoor_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../../../core/services/notification_service.dart';
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _selectedIndex = 0; // Renamed from _currentIndex

  final List<Widget> _screens = [
    const MapScreen(),
    const WalksListScreen(),
    const NextdoorScreen(), // Changed from placeholder
    const ChatListScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) { // New method
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    // Initialize Notification Service
    NotificationService().initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack( // Changed body to IndexedStack
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex, // Changed to _selectedIndex
        onDestinationSelected: _onItemTapped, // Changed to _onItemTapped
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Mappa',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_walk_outlined),
            selectedIcon: Icon(Icons.directions_walk),
            label: 'Passeggiate',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined), // Changed icon
            selectedIcon: Icon(Icons.campaign), // Changed icon
            label: 'Nextdoor', // Changed label
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profilo',
          ),
        ],
      ),
    );
  }
}
