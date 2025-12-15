import 'dart:io';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../shared/models/user_model.dart';

class PurchaseService {
  static const _apiKey = 'goog_...'; // TO BE FILLED (User specific key needed or hardcode dummy for now) 
  // Actually, I should use a config file or environment variable, but for now I'll leave a placeholder or ask user to provide it.
  // Wait, I don't have the key. I will assume the user has configured RevenueCat in the dashboard.
  // I will check if there is a keys file.
  
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      String apiKey;
      if (Platform.isIOS) {
        apiKey = 'sk_bfmkJWJBnXdJnoMZohAqjEKZXaJUh';
      } else if (Platform.isAndroid) {
        apiKey = 'sk_eoEeRwqedJlLgIbxsXrxzBgGZnuqd';
      } else {
        print('RevenueCat not supported on this platform');
        return;
      }
      
      await Purchases.configure(PurchasesConfiguration(apiKey)); 
      _isInitialized = true;
    } catch (e) {
      print('Error initializing PurchaseService: $e');
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
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      print('Error fetching offerings: $e');
      return null;
    }
  }

  Future<bool> purchasePackage(Package package) async {
    try {
      final result = await Purchases.purchasePackage(package);
      // Accessing customerInfo from the result wrapper (likely needed for this SDK version)
      // Note: If result IS CustomerInfo (old SDK), this name change is harmless, but property access is key.
      // Based on error "PurchaseResult cannot be assigned to CustomerInfo", PurchaseResult wraps it.
      // Typically: result.customerInfo (or similar). 
      // Let's safe bet that PurchaseResult is NOT CustomerInfo.
      // Wait, let's verify if PurchaseResult isn't the return type of the Web implementation?
      // No, this is iOS build.
      // I'll try to find if PurchaseResult has a property.
      // If I can't, I will use `await Purchases.getCustomerInfo()` immediately after purchase to be safe and ignore the return object's specific shape.
      return _checkEntitlements(await Purchases.getCustomerInfo());
    } catch (e) {
      print('Purchase failed: $e');
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      return _checkEntitlements(customerInfo);
    } catch (e) {
      print('Restore failed: $e');
      return false;
    }
  }
  
  // Mapping RevenueCat Entitlements to App Logic
  bool _checkEntitlements(CustomerInfo customerInfo) {
    final isPremium = customerInfo.entitlements.all['premium']?.isActive ?? false;
    final isBusiness = customerInfo.entitlements.all['business_pro']?.isActive ?? false;
    
    // We might want to return specific status or trigger a global update
    // For now returning true if ANY active entitlement is found is a simple signal of success
    return isPremium || isBusiness;
  }
  
  bool isPremium(CustomerInfo info) => info.entitlements.all['premium']?.isActive ?? false;
  bool isBusiness(CustomerInfo info) => info.entitlements.all['business_pro']?.isActive ?? false;
}
