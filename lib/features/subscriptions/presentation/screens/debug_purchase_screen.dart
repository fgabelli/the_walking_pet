import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../../core/services/purchase_service.dart';
import '../../../../shared/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DebugPurchaseScreen extends ConsumerStatefulWidget {
  const DebugPurchaseScreen({super.key});

  @override
  ConsumerState<DebugPurchaseScreen> createState() => _DebugPurchaseScreenState();
}

class _DebugPurchaseScreenState extends ConsumerState<DebugPurchaseScreen> {
  String _log = "Inizializzazione check...\n";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  void _appendLog(String line) {
    if (mounted) {
      setState(() {
        _log += "$line\n";
      });
    }
  }

  Future<void> _runDiagnostics() async {
    setState(() => _isLoading = true);
    _log = "--- DIAGNOSTICA ACQUISTI ---\n";
    
    try {
      final currentUser = ref.read(authServiceProvider).currentUser;
      _appendLog("1. Firebase User: ${currentUser?.uid ?? 'NULL'}");
      
      if (currentUser == null) {
        _appendLog("ERRORE: Utente non loggato in Firebase.");
        return;
      }

      final purchaseService = ref.read(purchaseServiceProvider);
      
      // Check RevenueCat ID
      final customerInfo = await purchaseService.getCustomerInfo();
      _appendLog("2. RevenueCat Info recuperate: ${customerInfo != null}");
      
      if (customerInfo != null) {
        _appendLog("   Original App User ID: ${customerInfo.originalAppUserId}");
        _appendLog("   Active Entitlements: ${customerInfo.entitlements.active.keys.join(', ')}");
        _appendLog("   All Entitlements: ${customerInfo.entitlements.all.keys.join(', ')}");
        _appendLog("   Latest Expiration: ${customerInfo.latestExpirationDate}");
      } else {
        _appendLog("ERRORE: Impossibile recuperare info da RevenueCat.");
      }

      // Check Firestore
      _appendLog("3. Verifica Firestore...");
      // Check Server Data (Bypass Cache)
      final docRef = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
      final serverDoc = await docRef.get(const GetOptions(source: Source.server));
      
      if (serverDoc.exists) {
        final data = serverDoc.data();
        _appendLog("   [SERVER] isPremium: ${data?['isPremium']}");
        _appendLog("   [SERVER] accountType: ${data?['accountType']}");
      } else {
        _appendLog("   [SERVER] Doc non trovato.");
      }

      // Check Local/Service Data
      final userModel = await ref.read(userServiceProvider).getUserById(currentUser.uid);
      
      if (userModel != null) {
        _appendLog("   Firestore isPremium: ${userModel.isPremium}");
        _appendLog("   Firestore accountType: ${userModel.accountType.name}");
      } else {
        _appendLog("ERRORE: UserModel non trovato in Firestore.");
      }

    } catch (e) {
      _appendLog("ECCEZIONE: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forceSync() async {
    _appendLog("\n--- AVVIO SINCRONIZZAZIONE FORZATA ---");
    setState(() => _isLoading = true);
    try {
      final currentUser = ref.read(authServiceProvider).currentUser;
      if (currentUser != null) {
        _appendLog("Identifying user: ${currentUser.uid}");
        await ref.read(purchaseServiceProvider).identifyUser(currentUser.uid);
        _appendLog("Sync completato logicamente.");
        
        // Final check
        final userModel = await ref.read(userServiceProvider).getUserById(currentUser.uid);
        _appendLog("Stato Finale Firestore isPremium: ${userModel?.isPremium}");
      }
    } catch (e) {
      _appendLog("ERRORE SYNC: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _runDiagnostics(); // Re-run complete check
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostica Acquisti')),
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.black,
              child: SingleChildScrollView(
                child: Text(
                  _log,
                  style: const TextStyle(
                    color: Colors.greenAccent, 
                    fontFamily: 'monospace', 
                    fontSize: 12
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _forceSync,
                icon: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Icon(Icons.sync),
                label: const Text('FORZA SINCRONIZZAZIONE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, 
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
