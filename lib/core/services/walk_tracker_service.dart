import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:latlong2/latlong.dart';
import 'package:pedometer/pedometer.dart';

// Stato della sessione
enum WalkStatus { inactive, active, paused }

class WalkSessionState {
  final WalkStatus status;
  final List<LatLng> routePoints;
  final DateTime? startTime;
  final double distanceKm;
  final int currentSteps; // Passi contati DURANTE la sessione (differenziale)

  WalkSessionState({
    this.status = WalkStatus.inactive,
    this.routePoints = const [],
    this.startTime,
    this.distanceKm = 0.0,
    this.currentSteps = 0,
  });

  WalkSessionState copyWith({
    WalkStatus? status,
    List<LatLng>? routePoints,
    DateTime? startTime,
    double? distanceKm,
    int? currentSteps,
  }) {
    return WalkSessionState(
      status: status ?? this.status,
      routePoints: routePoints ?? this.routePoints,
      startTime: startTime ?? this.startTime,
      distanceKm: distanceKm ?? this.distanceKm,
      currentSteps: currentSteps ?? this.currentSteps,
    );
  }
}

// Provider statale
final walkSessionProvider = StateNotifierProvider<WalkTrackerService, WalkSessionState>((ref) {
  return WalkTrackerService();
});

class WalkTrackerService extends StateNotifier<WalkSessionState> {
  StreamSubscription<StepCount>? _stepStream;
  LatLng? _lastPosition;
  int? _initialStepCount; // Passi dal boot al momento dello start
  bool _bgGeoConfigured = false;

  WalkTrackerService() : super(WalkSessionState());

  Future<void> startWalk() async {
    // 1. Setup state immediatamente per mostrare la UI come attiva
    state = WalkSessionState(
      status: WalkStatus.active,
      startTime: DateTime.now(),
      routePoints: [],
      distanceKm: 0.0,
      currentSteps: 0,
    );
    _lastPosition = null;
    _initialStepCount = null;

    // 2. Start Pedometer Stream (conteggio passi nativo dal sensore)
    _startPedometer();

    // 3. Configura e avvia BackgroundGeolocation
    if (!_bgGeoConfigured) {
      // Configura UNA SOLA VOLTA per tutta la vita dell'app
      bg.BackgroundGeolocation.onLocation((bg.Location location) {
        _processNewLocation(location);
      });

      bg.BackgroundGeolocation.onMotionChange((bg.Location location) {
        print('[BG_GEO] Motion changed: isMoving=${location.isMoving}');
        _processNewLocation(location);
      });

      bg.BackgroundGeolocation.onProviderChange((bg.ProviderChangeEvent event) {
        print('[BG_GEO] Provider changed: ${event.status}');
      });

      _bgGeoConfigured = true;
    }

    await bg.BackgroundGeolocation.ready(bg.Config(
      // — Tracking —
      desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
      distanceFilter: 5.0,
      stopOnTerminate: false,         // CONTINUA anche se l'app viene chiusa!
      startOnBoot: false,             // Non avviare al boot del telefono
      enableHeadless: true,           // Abilita esecuzione headless (Android)
      
      // — Activity Recognition —
      isMoving: true,                 // Inizia subito in modalità "moving"
      stopTimeout: 3,                 // Aspetta 3 minuti prima di decidere che sei fermo
      
      // — iOS Specifico —
      activityType: bg.Config.ACTIVITY_TYPE_FITNESS,
      pausesLocationUpdatesAutomatically: false,
      showsBackgroundLocationIndicator: true,
      
      // — Android Specifico —
      foregroundService: true,
      notification: bg.Notification(
        title: 'Passeggiata in corso',
        text: 'DOGZN sta tracciando la tua passeggiata',
        sticky: true,
      ),
      
      // — Logging (solo debug) —
      debug: kDebugMode,
      logLevel: kDebugMode ? bg.Config.LOG_LEVEL_VERBOSE : bg.Config.LOG_LEVEL_OFF,
      
      // — NON inviare dati a nessun server —
      url: '',
      autoSync: false,
      
      // — Permessi —
      locationAuthorizationRequest: 'Always',  // Chiedi "Sempre" su iOS
      backgroundPermissionRationale: bg.PermissionRationale(
        title: 'Accesso alla posizione in background',
        message: 'DOGZN raccoglie i dati sulla posizione per consentire il tracciamento del percorso e il calcolo della distanza anche quando l\'app è chiusa o non in uso.',
        positiveAction: 'Consenti',
        negativeAction: 'Annulla',
      ),
    ));

    // 4. Avvia il tracking
    await bg.BackgroundGeolocation.start();

    // 5. Forza un fix iniziale per centrare subito la mappa
    try {
      final location = await bg.BackgroundGeolocation.getCurrentPosition(
        extras: {'source': 'initial_fix'},
        timeout: 10,
        maximumAge: 5000,
        desiredAccuracy: 10,
        persist: false,
      );
      _processNewLocation(location);
    } catch (e) {
      print('[BG_GEO] Initial position failed: $e');
    }
  }

  /// Avvia il pedometer nativo per contare i passi reali dal sensore
  void _startPedometer() {
    try {
      _stepStream = Pedometer.stepCountStream.listen((StepCount event) {
        // Al primo evento, salviamo il conteggio iniziale come baseline
        _initialStepCount ??= event.steps;

        // Calcoliamo i passi fatti durante questa camminata (differenziale)
        final walkSteps = event.steps - _initialStepCount!;
        if (walkSteps >= 0) {
          state = state.copyWith(currentSteps: walkSteps);
        }
      }, onError: (error) {
        // Se il sensore non è disponibile, i passi resteranno a 0
        print("Pedometer error: $error");
      });
    } catch (e) {
      print("Pedometer init error: $e");
    }
  }

  void pauseWalk() {
    _stepStream?.pause();
    // Non fermiamo BackgroundGeolocation — mettiamo solo in pausa la nostra logica
    state = state.copyWith(status: WalkStatus.paused);
  }

  void resumeWalk() {
    _stepStream?.resume();
    state = state.copyWith(status: WalkStatus.active);
  }

  Future<void> stopWalk() async {
    await _stepStream?.cancel();
    _stepStream = null;
    
    // Ferma il tracking background
    await bg.BackgroundGeolocation.stop();
    
    // Non resettiamo subito lo stato perché la UI deve mostrare il recap finale
    state = state.copyWith(status: WalkStatus.inactive);
  }

  void reset() {
    _initialStepCount = null;
    state = WalkSessionState();
  }

  void _processNewLocation(bg.Location location) {
    // Non processiamo se la walk non è attiva (es. pausa)
    if (state.status != WalkStatus.active) return;
    
    final coords = location.coords;
    final newPoint = LatLng(coords.latitude, coords.longitude);

    // --- PRIMO PUNTO: accettiamo sempre per centrare la mappa ---
    if (state.routePoints.isEmpty) {
      final newPoints = List<LatLng>.from(state.routePoints)..add(newPoint);
      state = state.copyWith(routePoints: newPoints);
      _lastPosition = newPoint;
      print('[BG_GEO] First point: ${coords.latitude}, ${coords.longitude} (accuracy: ${coords.accuracy}m)');
      return;
    }

    // --- FILTRI QUALITÀ per punti successivi ---
    // 1. Ignora fix molto imprecisi (>30m di errore GPS)
    if (coords.accuracy > 30) {
      print('[BG_GEO] Skipping: accuracy ${coords.accuracy}m > 30m');
      return;
    }

    // 2. Anti-drift: BackgroundGeolocation ha già il suo motion detection,
    //    ma aggiungiamo un check extra: se speed < 0.3 m/s (~1 km/h)
    //    E distanza < 15m dal punto precedente, è drift.
    if (_lastPosition != null) {
      final distCalc = const Distance();
      final distFromLast = distCalc.distance(_lastPosition!, newPoint); // in meters
      
      if (coords.speed >= 0 && coords.speed < 0.3 && distFromLast < 15) {
        print('[BG_GEO] Skipping: drift (speed=${coords.speed}, dist=${distFromLast.round()}m)');
        return;
      }
    }

    // Calcolo distanza incrementale
    double addedDist = 0;
    if (_lastPosition != null) {
      final distCalc = const Distance();
      addedDist = distCalc.distance(_lastPosition!, newPoint) / 1000.0;
      
      // Sanity check: se un singolo segmento supera 500m, è un salto GPS.
      // Lo registriamo come punto ma NON aggiungiamo la distanza.
      if (addedDist > 0.5) {
        print('[BG_GEO] GPS jump: ${(addedDist * 1000).round()}m — point added, distance ignored');
        addedDist = 0;
      }
    }

    final newPoints = List<LatLng>.from(state.routePoints)..add(newPoint);
    
    state = state.copyWith(
      routePoints: newPoints,
      distanceKm: state.distanceKm + addedDist,
    );
    
    _lastPosition = newPoint;
    print('[BG_GEO] Point #${newPoints.length}: +${(addedDist * 1000).round()}m, total=${state.distanceKm.toStringAsFixed(3)}km');
  }
}
