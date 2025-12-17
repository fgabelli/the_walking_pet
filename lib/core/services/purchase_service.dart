import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../shared/models/user_model.dart';
import '../services/user_service.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/profile/presentation/providers/profile_provider.dart'; // Added for userServiceProvider

class PurchaseService {
  final Ref _ref; // Added to access other providers
  
  PurchaseService(this._ref);

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      String apiKey;
      if (Platform.isIOS) {
        apiKey = 'appl_iDvNyOMRufxukhtmMEpLdtaufyJ';
      } else if (Platform.isAndroid) {
        apiKey = 'sk_eoEeRwqedJlLgIbxsXrxzBgGZnuqd';
      } else {
        print('RevenueCat not supported on this platform');
        return;
      }
      
      await Purchases.configure(PurchasesConfiguration(apiKey)); 
      _isInitialized = true;
      
      // Listen to subscription updates
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        _syncWithFirestore(customerInfo);
      });
      
      // Initial sync
      final info = await Purchases.getCustomerInfo();
      _syncWithFirestore(info);

    } catch (e) {
      print('Error initializing PurchaseService: $e');
    }
  }

  Future<void> identifyUser(String userId) async {
    if (!_isInitialized) await init();
    try {
      print('PURCHASE: Identifying user $userId...');
      final result = await Purchases.logIn(userId);
      print('PURCHASE: LogIn Result (Created=${result.created})');
      
      // Sync immediately
      bool isActive = await _syncWithFirestore(result.customerInfo);
      
      // If result is false, maybe it needs a refresh?
      if (!isActive) {
         print('PURCHASE: Initial sync was false. Forcing refresh of CustomerInfo...');
         try {
           final info = await Purchases.getCustomerInfo();
           await _syncWithFirestore(info);
         } catch(e) {
           print('PURCHASE: Error refreshing info: $e');
         }
      }
      
    } catch (e) {
      print('Error identifying user: $e');
    }
  }

  Future<CustomerInfo?> getCustomerInfo() async {
    try {
      return await Purchases.getCustomerInfo();
    } catch (e) {
      print('Error fetching customer info: $e');
      return null;
    }
  }

  Future<Offerings?> getOfferings() async {
    // try-catch removed to allow UI to catch and display the actual error
    return await Purchases.getOfferings();
  }

  Future<bool> purchasePackage(Package package) async {
    try {
      await Purchases.purchasePackage(package);
      final info = await Purchases.getCustomerInfo();
      return _syncWithFirestore(info);
    } catch (e) {
      print('Purchase failed: $e');
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      return _syncWithFirestore(customerInfo);
    } catch (e) {
      print('Restore failed: $e');
      return false;
    }
  }
  
  Future<void> logout() async {
    try {
      await Purchases.logOut();
    } catch (e) {
      print('Error logging out of RevenueCat: $e');
    }
  }
  
  Future<bool> _syncWithFirestore(CustomerInfo customerInfo) async {
    final isPremium = customerInfo.entitlements.all['premium']?.isActive ?? false;
    final isBusiness = customerInfo.entitlements.all['business_pro']?.isActive ?? false;
    
    // Business includes Premium benefits usually, or at least we treat them as "Premium" for unlocking features
    // Strict check for specific entitlements to distinguish account types
    // Business includes Premium benefits usually, or at least we treat them as "Premium" for unlocking features
    // Strict check for specific entitlements to distinguish account types
    final hasActiveEntitlement = isPremium || isBusiness;
    
    if (!isBusiness && customerInfo.entitlements.all.containsKey('business_pro')) {
       print('PURCHASE: business_pro FOUND but not active. Expiration: ${customerInfo.entitlements.all['business_pro']?.expirationDate}');
    }
    
    print('Purchase Sync: Active Entitlements=${customerInfo.entitlements.active.keys}');
    print('Purchase Sync: ALL Entitlements=${customerInfo.entitlements.all.keys}');
    print('Status: Premium=$isPremium, Business=$isBusiness => Unlock Features=$hasActiveEntitlement');

    try {
      final currentUserAuth = _ref.read(authServiceProvider).currentUser;
      if (currentUserAuth != null) {
        print('SYNC: Fetching latest user data for ${currentUserAuth.uid}...');
        // Force server fetch to ensure we are comparing against truth
        // We use the service but we accept that the service might cache. 
        // Ideally we should force refresh here too?
        // Let's rely on getUserById for now but log the result.
        final userModel = await _ref.read(userServiceProvider).getUserById(currentUserAuth.uid);
        
        if (userModel != null) {
          print('SYNC: Current DB State -> isPremium: ${userModel.isPremium}, accountType: ${userModel.accountType}');
          final Map<String, dynamic> updates = {};

          // 1. Sync Premium Status
          if (userModel.isPremium != hasActiveEntitlement) {
            print('SYNC: Logic -> Updating isPremium from ${userModel.isPremium} to $hasActiveEntitlement');
            updates['isPremium'] = hasActiveEntitlement;
          }

          // 2. Sync Business Status
          if (isBusiness && userModel.accountType != AccountType.business) {
             print('SYNC: Logic -> Updating accountType from ${userModel.accountType} to business');
             updates['accountType'] = AccountType.business.name;
          } else if (!isBusiness && userModel.accountType == AccountType.business) {
             print('SYNC: WARNING -> User is Business in DB but RC says NOT Business. (Expired?) keeping DB as Business for grace period or manual downgrade?');
             // Optionally we could downgrade here: updates['accountType'] = AccountType.personal.name;
          }
          
          if (updates.isNotEmpty) {
            print('SYNC: Executing Firestore Write: $updates');
            await _ref.read(userServiceProvider).updateUserFields(
              currentUserAuth.uid, 
              updates
            );
            print('SYNC: Firestore Write Completed.');
          } else {
            print('SYNC: No updates required.');
          }
        } else {
             print('SYNC: User Model is null!');
        }
      }
    } catch (e, stack) {
      print('Error syncing with Firestore: $e\n$stack');
    }
    
    return hasActiveEntitlement;
  }
  
  bool isPremium(CustomerInfo info) => info.entitlements.all['premium']?.isActive ?? false;
  bool isBusiness(CustomerInfo info) => info.entitlements.all['business_pro']?.isActive ?? false;
  
  /// Returns the management URL for the active platform store
  /// Note: RevenueCat's customerInfo.managementURL is often null on Android until configured or specific cases.
  /// We can fall back to standard store URLs if needed.
  Future<String?> getManagementURL() async {
    final customerInfo = await getCustomerInfo();
    if (customerInfo?.managementURL != null) {
      return customerInfo!.managementURL;
    }
    // Fallback based on platform if specific URL is missing (often happens in sandbox)
    if (Platform.isIOS) {
       return 'https://apps.apple.com/account/subscriptions';
    } else if (Platform.isAndroid) {
       return 'https://play.google.com/store/account/subscriptions';
    }
    return null;
  }
  
  EntitlementInfo? getActiveEntitlement(CustomerInfo info) {
    if (info.entitlements.all['business_pro']?.isActive ?? false) {
      return info.entitlements.all['business_pro'];
    }
    if (info.entitlements.all['premium']?.isActive ?? false) {
      return info.entitlements.all['premium'];
    }
    return null;
  }
}

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  return PurchaseService(ref);
});
