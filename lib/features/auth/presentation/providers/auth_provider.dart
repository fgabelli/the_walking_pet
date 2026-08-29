import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/purchase_service.dart';
import '../../../../core/services/notification_service.dart';

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

/// Auth Controller
class AuthController extends StateNotifier<AuthState> {
  final AuthService _authService;
  final PurchaseService _purchaseService; 
  final NotificationService _notificationService;

  AuthController(this._authService, this._purchaseService, this._notificationService) : super(AuthState());

  Future<void> signInWithEmail(String email, String password) async {
    state = AuthState(isLoading: true);
    try {
      final credential = await _authService.signInWithEmail(email: email, password: password);
      // Access .user property
      if (credential.user != null) {
        await _purchaseService.identifyUser(credential.user!.uid);
        await _notificationService.updateToken();
      }
      state = AuthState(isLoading: false);
    } catch (e) {
      state = AuthState(isLoading: false, error: e.toString());
    }
  }

  Future<void> registerWithEmail(String email, String password) async {
    state = AuthState(isLoading: true);
    try {
      final credential = await _authService.registerWithEmail(email: email, password: password);
       if (credential.user != null) {
        await _purchaseService.identifyUser(credential.user!.uid);
        await _notificationService.updateToken();
      }
      state = AuthState(isLoading: false);
    } catch (e) {
      state = AuthState(isLoading: false, error: e.toString());
    }
  }

  Future<void> signInWithGoogle() async {
    state = AuthState(isLoading: true);
    try {
      final credential = await _authService.signInWithGoogle();
       if (credential.user != null) {
        await _purchaseService.identifyUser(credential.user!.uid);
        await _notificationService.updateToken();
      }
      state = AuthState(isLoading: false);
    } catch (e) {
      state = AuthState(isLoading: false, error: e.toString());
    }
  }

  Future<void> signInWithApple() async {
    state = AuthState(isLoading: true);
    try {
      final result = await _authService.signInWithApple();
       if (result.credential.user != null) {
        await _purchaseService.identifyUser(result.credential.user!.uid);
        await _notificationService.updateToken();
        
        // Store name components if available (Apple only sends them on first login)
        if (result.givenName != null || result.familyName != null) {
          try {
            String displayName = '';
            if (result.givenName != null) displayName += result.givenName!;
            if (result.familyName != null) displayName += ' ${result.familyName!}';
            
            if (displayName.trim().isNotEmpty) {
               await result.credential.user!.updateDisplayName(displayName.trim());
               await result.credential.user!.reload(); // Sync local user
            }
          } catch (e) {
            print("Error updating Apple DisplayName: $e");
          }
        }
      }
      state = AuthState(isLoading: false);
    } catch (e) {
      state = AuthState(isLoading: false, error: e.toString());
    }
  }
  
  Future<void> signOut() async {
    state = AuthState(isLoading: true);
    try {
      // [FIX] Delete token BEFORE signing out — user must still be authenticated
      // so deleteToken() can read currentUser.uid and remove the token from Firestore.
      await _notificationService.deleteToken();
      await _authService.signOut();
      await _purchaseService.logout(); 
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
    ref.watch(notificationServiceProvider),
  );
});
