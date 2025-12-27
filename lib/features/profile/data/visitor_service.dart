import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Simple model for a Visitor
class VisitorModel {
  final String visitorId;
  final DateTime lastVisit;
  final int visitCount;

  VisitorModel({
    required this.visitorId,
    required this.lastVisit,
    required this.visitCount,
  });

  factory VisitorModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VisitorModel(
      visitorId: doc.id,
      lastVisit: (data['lastVisit'] as Timestamp).toDate(),
      visitCount: data['visitCount'] ?? 1,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'lastVisit': Timestamp.fromDate(lastVisit),
      'visitCount': visitCount,
    };
  }
}

/// Visitor Service Provider
final visitorServiceProvider = Provider<VisitorService>((ref) {
  return VisitorService();
});

class VisitorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Record a visit
  Future<void> recordVisit(String targetUserId, String visitorId) async {
    if (targetUserId == visitorId) return; // Don't track self visits

    final docRef = _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('visitors')
        .doc(visitorId);

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);

        if (snapshot.exists) {
           // Update existing
           final currentCount = snapshot.get('visitCount') ?? 0;
           transaction.update(docRef, {
             'lastVisit': FieldValue.serverTimestamp(),
             'visitCount': currentCount + 1,
           });
        } else {
           // Create new
           transaction.set(docRef, {
             'lastVisit': FieldValue.serverTimestamp(),
             'visitCount': 1,
           });
        }
      });
    } catch (e) {
      print('Error recording visit: $e');
      // Non-critical, supress error
    }
  }

  // Get visitors stream
  Stream<List<VisitorModel>> getVisitorsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('visitors')
        .orderBy('lastVisit', descending: true)
        .limit(50) // Limit to last 50 for performance
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => VisitorModel.fromFirestore(doc)).toList());
  }
}
