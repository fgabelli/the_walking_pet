import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/models/safety_alert_model.dart'; // Added
import '../shared/models/safety_alert_model.dart';

class SafetyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add a new alert (lasts 24 hours by default)
  Future<void> reportDanger({
    required String authorId,
    required SafetyAlertType type,
    required double latitude,
    required double longitude,
    String? description,
  }) async {
    final now = DateTime.now();
    final expires = now.add(const Duration(hours: 24));

    final alert = SafetyAlertModel(
      id: '', // Firestore generates ID
      authorId: authorId,
      type: type,
      latitude: latitude,
      longitude: longitude,
      description: description,
      createdAt: now,
      expiresAt: expires,
    );

    await _firestore.collection('safety_alerts').add(alert.toFirestore());
  }

  // Get active alerts (not expired)
  Stream<List<SafetyAlertModel>> getActiveAlertsStream() {
    final now = DateTime.now();
    return _firestore
        .collection('safety_alerts')
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => SafetyAlertModel.fromFirestore(doc)).toList();
    });
  }
  
  // Delete useful for moderation or if user removes their own report
  Future<void> deleteAlert(String alertId) async {
    await _firestore.collection('safety_alerts').doc(alertId).delete();
  }
}
