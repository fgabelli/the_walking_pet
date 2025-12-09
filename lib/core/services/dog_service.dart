import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/models/dog_model.dart';

/// Dog service for Firestore operations
class DogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'dogs';

  // Get dog by ID
  Future<DogModel?> getDogById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        return DogModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Get dogs by owner ID
  Future<List<DogModel>> getDogsByOwnerId(String ownerId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('ownerId', isEqualTo: ownerId)
          .get();
      return snapshot.docs.map((doc) => DogModel.fromFirestore(doc)).toList();
    } catch (e) {
      rethrow;
    }
  }

  // Get dogs stream by owner ID
  Stream<List<DogModel>> getDogsStreamByOwnerId(String ownerId) {
    return _firestore
        .collection(_collection)
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => DogModel.fromFirestore(doc)).toList());
  }

  // Create dog
  Future<String> createDog(DogModel dog) async {
    try {
      final docRef = await _firestore
          .collection(_collection)
          .add(dog.toFirestore());
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  // Update dog
  Future<void> updateDog(DogModel dog) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(dog.id)
          .update(dog.toFirestore());
    } catch (e) {
      rethrow;
    }
  }

  // Delete dog
  Future<void> deleteDog(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      rethrow;
    }
  }

  // Get dogs by size
  Future<List<DogModel>> getDogsBySize(DogSize size) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('size', isEqualTo: size.name)
          .get();
      return snapshot.docs.map((doc) => DogModel.fromFirestore(doc)).toList();
    } catch (e) {
      rethrow;
    }
  }

  // Get dogs by energy level range
  Future<List<DogModel>> getDogsByEnergyLevel(int minLevel, int maxLevel) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('energyLevel', isGreaterThanOrEqualTo: minLevel)
          .where('energyLevel', isLessThanOrEqualTo: maxLevel)
          .get();
      return snapshot.docs.map((doc) => DogModel.fromFirestore(doc)).toList();
    } catch (e) {
      rethrow;
    }
  }
}
