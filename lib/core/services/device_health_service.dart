import 'dart:io';
import 'package:health/health.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final deviceHealthServiceProvider = Provider<DeviceHealthService>((ref) => DeviceHealthService());

class DeviceHealthService {
  final Health _health = Health();

  /// On Android, Health Connect is disabled (Play Store policy).
  /// On iOS, HealthKit works normally.
  bool get _isSupported => Platform.isIOS;

  /// Tipi di dati che vogliamo leggere/scrivere
  static final _types = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.WORKOUT,
    HealthDataType.DISTANCE_DELTA,
  ];
  
  static final _permissions = [
    HealthDataAccess.READ,       // Steps: solo lettura
    HealthDataAccess.WRITE,      // Calories: solo scrittura
    HealthDataAccess.WRITE,      // Workout: solo scrittura
    HealthDataAccess.WRITE,      // Distance: solo scrittura
  ];

  Future<bool> requestPermissions() async {
    if (!_isSupported) return false;
    bool requested = await _health.requestAuthorization(_types, permissions: _permissions);
    return requested;
  }

  /// Legge i passi effettuati nell'intervallo di tempo dato
  Future<int> fetchSteps(DateTime startTime, DateTime endTime) async {
    if (!_isSupported) return 0;
    try {
      int? steps = await _health.getTotalStepsInInterval(startTime, endTime);
      return steps ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Salva una sessione di camminata come "Allenamento"
  Future<bool> saveWalkSession({
    required DateTime startTime,
    required DateTime endTime,
    required int steps,
    required int caloriesBurned,
    required double distanceMeters,
  }) async {
    if (!_isSupported) return false;
    try {
      bool success = await _health.writeWorkoutData(
        activityType: HealthWorkoutActivityType.WALKING, 
        start: startTime, 
        end: endTime, 
        totalEnergyBurned: caloriesBurned,
        totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
        totalDistance: distanceMeters.toInt(),
        totalDistanceUnit: HealthDataUnit.METER,
      );
      
      return success;
    } catch (e) {
      print("Errore salvataggio Salute: $e");
      return false;
    }
  }
}
