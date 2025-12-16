import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/auth_service.dart';

/// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Auth State Stream Provider
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Auth Controller State
class AuthState {
  final bool isLoading;
  final String? error;

  AuthState({this.isLoading = false, this.error});
}

import '../../../../core/services/purchase_service.dart'; // Added import

/// Auth Controller
class AuthController extends StateNotifier<AuthState> {
  final AuthService _authService;
  final PurchaseService _purchaseService; // Added

  AuthController(this._authService, this._purchaseService) : super(AuthState());

  Future<void> signInWithEmail(String email, String password) async {
    state = AuthState(isLoading: true);
    try {
      final user = await _authService.signInWithEmail(email: email, password: password);
      if (user != null) {
        await _purchaseService.identifyUser(user.uid);
      }
      state = AuthState(isLoading: false);
    } catch (e) {
      state = AuthState(isLoading: false, error: e.toString());
    }
  }

  Future<void> registerWithEmail(String email, String password) async {
    state = AuthState(isLoading: true);
    try {
      final user = await _authService.registerWithEmail(email: email, password: password);
       if (user != null) {
        await _purchaseService.identifyUser(user.uid);
      }
      state = AuthState(isLoading: false);
    } catch (e) {
      state = AuthState(isLoading: false, error: e.toString());
    }
  }

  Future<void> signInWithGoogle() async {
    state = AuthState(isLoading: true);
    try {
      final user = await _authService.signInWithGoogle();
       if (user != null) {
        await _purchaseService.identifyUser(user.uid);
      }
      state = AuthState(isLoading: false);
    } catch (e) {
      state = AuthState(isLoading: false, error: e.toString());
    }
  }

  Future<void> signInWithApple() async {
    state = AuthState(isLoading: true);
    try {
      final user = await _authService.signInWithApple();
       if (user != null) {
        await _purchaseService.identifyUser(user.uid);
      }
      state = AuthState(isLoading: false);
    } catch (e) {
      state = AuthState(isLoading: false, error: e.toString());
    }
  }
  
  // ... signOut remains same
  Future<void> signOut() async {
    state = AuthState(isLoading: true);
    try {
      await _authService.signOut();
      // Optionally reset purchases identity? RevenueCat handles logOut automatically if we want
      // await Purchases.logOut(); 
      state = AuthState(isLoading: false);
    } catch (e) {
      state = AuthState(isLoading: false, error: e.toString());
    }
  }
}

/// Auth Controller Provider
final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.watch(authServiceProvider),
    ref.watch(purchaseServiceProvider),
  );
});
