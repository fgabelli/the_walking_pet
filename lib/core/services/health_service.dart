import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/health_record_model.dart';

final healthServiceProvider = Provider<HealthService>((ref) {
  return HealthService();
});

class HealthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection reference: users/{ownerId}/dogs/{dogId}/health_records/{recordId}
  // WAIT: Ideally we should store this either under the dog document or a top level collection.
  // Given we query by petId, top level 'health_records' or subcollection of dog is fine.
  // Subcollection of dog is better for hierarchy: users/{uid}/dogs/{dogId}/health_records
  
  // BUT: fetching dogs is currently done via users/{uid}/dogs collection.
  // Let's stick to: users/{ownerId}/dogs/{petId}/health_records
  // Problem: We need ownerId to build the path. 
  // If we only have petId, we might need a trusted way to find owner.
  // However, usually we have the dog object which has ownerId.
  
  // Alternative: Top-level `health_records` collection with `petId` field.
  // This is easier for querying specific pet records without knowing owner path.
  // Let's go with Top-Level `health_records` indexed by `petId`. 
  // Easier for "Transfering ownership" (if that ever happens) and querying.

  CollectionReference get _healthRef => _firestore.collection('health_records');

  Future<void> addHealthRecord(HealthRecordModel record) async {
    await _healthRef.add(record.toFirestore());
  }

  Future<void> updateHealthRecord(HealthRecordModel record) async {
    await _healthRef.doc(record.id).update(record.toFirestore());
  }

  Future<void> deleteHealthRecord(String recordId) async {
    await _healthRef.doc(recordId).delete();
  }

  Stream<List<HealthRecordModel>> getHealthRecordsStream(String petId) {
    return _healthRef
        .where('petId', isEqualTo: petId)
        .snapshots() // Removed orderBy to avoid index issues
        .map((snapshot) {
      final records = snapshot.docs
          .map((doc) => HealthRecordModel.fromFirestore(doc))
          .toList();
      
      // Sort client-side
      records.sort((a, b) => b.date.compareTo(a.date));
      return records;
    });
  }
}
