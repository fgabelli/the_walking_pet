import 'package:cloud_firestore/cloud_firestore.dart';
import '../shared/models/lost_pet_alert_model.dart';

class SOSService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Trigger SOS
  Future<void> triggerSOS({
    required String ownerId,
    required String petId,
    required double latitude,
    required double longitude,
    required String contactPhone,
    String? message,
  }) async {
    final alert = LostPetAlertModel(
      id: '', // Generated
      ownerId: ownerId,
      petId: petId,
      latitude: latitude,
      longitude: longitude,
      contactPhone: contactPhone,
      message: message,
      createdAt: DateTime.now(),
      isActive: true,
    );

    // Add to 'sos_alerts' collection
    await _firestore.collection('sos_alerts').add(alert.toFirestore());
  }

  // Resolve SOS (Mark inactive)
  Future<void> resolveSOS(String alertId) async {
    await _firestore.collection('sos_alerts').doc(alertId).update({'isActive': false});
  }

  // Get Active SOS Stream
  Stream<List<LostPetAlertModel>> getActiveSOSStream() {
    return _firestore
        .collection('sos_alerts')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => LostPetAlertModel.fromFirestore(doc)).toList();
    });
  }
}
