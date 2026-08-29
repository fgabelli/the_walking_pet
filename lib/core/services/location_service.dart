import 'dart:async';
import 'package:geolocator/geolocator.dart';
class LocationService {
  /// Request location permission
  Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  /// Check if location service is enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Get last known position (Fast)
  Future<Position?> getLastKnownPosition() async {
    return await Geolocator.getLastKnownPosition();
  }

  /// Get current position (Precise but slower)
  Future<Position> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Check Service
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('I servizi di localizzazione sono disabilitati.');
    }

    // 2. Check Permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('I permessi di localizzazione sono stati negati.');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw Exception('I permessi di localizzazione sono permanentemente negati.');
    }

    // 3. Get Position
    // We throw generic timeout/error from Geolocator if this fails
    try {
      return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium, // Changed to medium for better Wi-Fi compatibility
          timeLimit: const Duration(seconds: 10)); // Reduced timeout with fallback
    } on TimeoutException {
      final lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null) {
        return lastPosition;
      }
      throw Exception('Impossibile ottenere la posizione (Timeout). Verifica il segnale GPS.');
    }
  }

  /// Get position stream
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5, // Update more frequently (every 5 meters) to catch small moves
      ),
    );
  }

  /// Calculate distance between two points in meters
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }
}
