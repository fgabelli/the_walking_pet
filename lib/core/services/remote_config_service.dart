import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  final FirebaseRemoteConfig _remoteConfig;
  static const String keyDatingEnabled = 'dating_enabled';

  RemoteConfigService({FirebaseRemoteConfig? remoteConfig})
      : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

  /// Inizializza il servizio Remote Config con default lato codice a false.
  Future<void> init({void Function(bool datingEnabled)? onDatingChanged}) async {
    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(hours: 1),
      ));

      // Default fondamentale: false (pausa dating garantita anche offline)
      await _remoteConfig.setDefaults(const {
        keyDatingEnabled: false,
      });

      await _remoteConfig.fetchAndActivate();
      onDatingChanged?.call(isDatingEnabled);

      // Ascolto in tempo reale se la configurazione viene aggiornata da console
      _remoteConfig.onConfigUpdated.listen((event) async {
        try {
          await _remoteConfig.activate();
          onDatingChanged?.call(isDatingEnabled);
        } catch (e) {
          debugPrint('[RemoteConfigService] Errore attivazione config aggiornata: $e');
        }
      });
    } catch (e) {
      debugPrint('[RemoteConfigService] Init error (utilizzando default false): $e');
    }
  }

  /// Restituisce se il dating è abilitato.
  /// In caso di errore o assenza rete, fallback rigoroso su false.
  bool get isDatingEnabled {
    try {
      return _remoteConfig.getBool(keyDatingEnabled);
    } catch (e) {
      debugPrint('[RemoteConfigService] Errore lettura $keyDatingEnabled: $e');
      return false;
    }
  }
}

final remoteConfigServiceProvider = Provider<RemoteConfigService>((ref) {
  return RemoteConfigService();
});

final datingEnabledProvider = StateProvider<bool>((ref) {
  final service = ref.watch(remoteConfigServiceProvider);
  return service.isDatingEnabled;
});
