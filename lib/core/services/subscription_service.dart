import 'dart:io';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../core/services/user_service.dart';

// REVENUECAT API KEYS (Replace with real keys later)
const _googleApiKey = "goog_placeholder_key"; // TODO: Configure in RC Dashboard
const _appleApiKey = "appl_placeholder_key";   // TODO: Configure in RC Dashboard

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService(ref);
});

class SubscriptionService {
  final Ref _ref;
  bool _isInitialized = false;

  SubscriptionService(this._ref);

  Future<void> init() async {
    if (_isInitialized) return;

    // await Purchases.setLogLevel(LogLevel.debug);

    PurchasesConfiguration? configuration;
    if (Platform.isAndroid) {
      // configuration = PurchasesConfiguration(_googleApiKey);
    } else if (Platform.isIOS) {
      // configuration = PurchasesConfiguration(_appleApiKey);
    }
    
    // Skip init if no keys provided yet to prevent crash
    if (configuration != null) {
      await Purchases.configure(configuration);
      _isInitialized = true;
    } else {
        print("RevenueCat not configured: Missing Keys");
    }
  }

  Future<void> logIn(String userId) async {
    if (!_isInitialized) return;
    try {
      await Purchases.logIn(userId);
      await checkSubscriptionStatus();
    } catch (e) {
      print("Error logging in to Purchases: $e");
    }
  }

  Future<void> logOut() async {
    if (!_isInitialized) return;
    try {
      await Purchases.logOut();
    } catch (e) {
       print("Error logging out from Purchases: $e");
    }
  }

  Future<void> checkSubscriptionStatus() async {
    if (!_isInitialized) return;
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final isPremium = customerInfo.entitlements.all['premium']?.isActive ?? false;
      
      // Update Firestore if status changed
      final currentUser = _ref.read(authServiceProvider).currentUser;
      if (currentUser != null) {
          final userModel = await UserService().getUserById(currentUser.uid);
          if (userModel != null && userModel.isPremium != isPremium) {
              final updatedUser = userModel.copyWith(isPremium: isPremium);
               await UserService().updateUser(updatedUser);
          }
      }
    } catch (e) {
      print("Error checking subscription status: $e");
    }
  }

  Future<List<Package>> getOfferings() async {
    if (!_isInitialized) return [];
    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null && offerings.current!.availablePackages.isNotEmpty) {
        return offerings.current!.availablePackages;
      }
    } catch (e) {
      print("Error fetching offerings: $e");
    }
    return [];
  }

  Future<bool> purchasePackage(Package package) async {
    if (!_isInitialized) return false;
    try {
      // purchasePackage returns CustomerInfo directly in newer versions, or we might need to verify the return type.
      // According to docs: Future<CustomerInfo> purchasePackage(Package package)
      // Build fix: Handle potential PurchaseResult wrapper or direct CustomerInfo
      final dynamic result = await Purchases.purchasePackage(package);
      CustomerInfo customerInfo;
      
      // Check if result has .customerInfo property (PurchaseResult wrapper) or is CustomerInfo itself
      try {
        customerInfo = result as CustomerInfo;
      } catch (_) {
         // Assume it's PurchaseResult with customerInfo field
         customerInfo = (result as dynamic).customerInfo;
      }

      final isPremium = customerInfo.entitlements.all['premium']?.isActive ?? false;
      
      if (isPremium) {
         // Sync with firestore immediately
         await checkSubscriptionStatus();
      }
      
      return isPremium;
    } catch (e) {
      if (e is PlatformException) {
        final errorCode = PurchasesErrorHelper.getErrorCode(e);
        if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
           print("User cancelled purchase");
        } else {
           print("Purchase error: $e");
        }
      }
      return false;
    }
  }

  Future<bool> restorePurchases() async {
      if (!_isInitialized) return false;
      try {
          final customerInfo = await Purchases.restorePurchases();
          final isPremium = customerInfo.entitlements.all['premium']?.isActive ?? false;
          await checkSubscriptionStatus();
          return isPremium;
      } catch (e) {
          print("Error restoring purchases: $e");
          return false;
      }
  }
}
