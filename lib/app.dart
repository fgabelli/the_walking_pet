import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/blocked_user_screen.dart';
import 'features/profile/presentation/providers/profile_provider.dart';
import 'features/profile/presentation/screens/create_profile_screen.dart';
import 'features/home/presentation/screens/main_screen.dart';

import 'package:upgrader/upgrader.dart';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'core/services/notification_router.dart';

class TheWalkingPetApp extends ConsumerWidget {
  const TheWalkingPetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Registra WidgetRef per permettere a NotificationRouter di cambiare tab
    NotificationRouter.ref = ref;

    return MaterialApp(
      title: 'DOGZN',
      debugShowCheckedModeBanner: false,
      navigatorKey: NotificationRouter.navigatorKey,
      
      // Analytics
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      ],
      
      // Theme
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      
      // Localization
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('it', 'IT'),
      ],
      
      // Home
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authStateAsync = ref.watch(authStateProvider);

    return authStateAsync.when(
      data: (user) {
        if (user != null) {
          // User is logged in, check if profile exists
          final profileAsync = ref.watch(currentUserProfileProvider);
          
          return profileAsync.when(
            data: (profile) {
              if (profile != null) {
                if (profile.isBanned) {
                  return const BlockedUserScreen();
                }
                return UpgradeAlert(
                  showIgnore: false,
                  showLater: true,
                  dialogStyle: UpgradeDialogStyle.cupertino,
                  child: const MainScreen(),
                );
              } else {
                return const CreateProfileScreen();
              }
            },
            loading: () => const SplashScreen(),
            error: (e, st) => Scaffold(body: Center(child: Text('Error: $e'))),
          );
        } else {
          // User is not logged in, show Login Screen
          return const LoginScreen();
        }
      },
      loading: () => const SplashScreen(),
      error: (e, st) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

// Temporary splash screen
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // DOGZN horizontal logo (dark text, transparent bg)
            Image.asset(
              'assets/images/dogzn/dogzn_logo.png',
              width: 240,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            Text(
              'The Walking Pet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[400],
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0A2342)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
