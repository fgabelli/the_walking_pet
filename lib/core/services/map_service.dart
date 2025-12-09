import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import '../../shared/models/user_model.dart';

class MapService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'user_locations'; // Separate collection for locations

  // Update user location
  Future<void> updateUserLocation(String uid, double latitude, double longitude) async {
    final GeoFirePoint geoPoint = GeoFirePoint(GeoPoint(latitude, longitude));
    
    await _firestore.collection(_collection).doc(uid).set({
      'uid': uid,
      'geo': geoPoint.data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Get nearby users
  // Returns a stream of documents with distance data
  Stream<List<UserLocation>> getNearbyUsers({
    required double latitude,
    required double longitude,
    required double radiusInKm,
  }) {
    final GeoFirePoint center = GeoFirePoint(GeoPoint(latitude, longitude));
    final ref = _collectionReference;

    return GeoCollectionReference(ref).subscribeWithin(
      center: center,
      radiusInKm: radiusInKm,
      field: 'geo',
      geopointFrom: (data) => (data['geo'] as Map<String, dynamic>)['geopoint'] as GeoPoint,
    ).map((snapshots) {
      return snapshots.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        // We might need to fetch full user profile separately or duplicate minimal data here
        // For now, let's assume we just return the location data and UID
        return UserLocation.fromMap(data, doc.id);
      }).toList();
    });
  }

  CollectionReference<Map<String, dynamic>> get _collectionReference =>
      _firestore.collection(_collection);
}

class UserLocation {
  final String uid;
  final double latitude;
  final double longitude;
  final DateTime? updatedAt;

  UserLocation({
    required this.uid,
    required this.latitude,
    required this.longitude,
    this.updatedAt,
  });

  factory UserLocation.fromMap(Map<String, dynamic> data, String id) {
    final geoData = data['geo'] as Map<String, dynamic>;
    final geoPoint = geoData['geopoint'] as GeoPoint;
    
    return UserLocation(
      uid: data['uid'] ?? id,
      latitude: geoPoint.latitude,
      longitude: geoPoint.longitude,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
