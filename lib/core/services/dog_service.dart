import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/models/dog_model.dart';
import 'analytics_service.dart';

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
      await AnalyticsService.petProfiloCreato(
        taglia: dog.size.name,
        eta: dog.age,
        specie: dog.species.name,
      );
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
  // Search dogs with multiple filters
  Future<List<DogModel>> searchDogs({
    List<PetSpecies>? species, // Changed to List
    List<DogSize>? sizes,
    List<DogGender>? genders,
    String? breedQuery,
    bool? isSterilized,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore.collection(_collection);
      bool usedWhereIn = false;

      // 1. Filter by Species
      if (species != null && species.isNotEmpty) {
        if (species.length == 1) {
          query = query.where('species', isEqualTo: species.first.name);
        } else {
           // Multiple species -> Use whereIn
           query = query.where('species', whereIn: species.map((e) => e.name).toList());
           usedWhereIn = true;
        }
      }

      // 2. Filter by Size
      // Firestore allows only one 'whereIn' per query.
      bool filterSizeClientSide = false;
      if (sizes != null && sizes.isNotEmpty) {
        if (!usedWhereIn) {
           query = query.where('size', whereIn: sizes.map((e) => e.name).toList());
           usedWhereIn = true;
        } else {
           filterSizeClientSide = true;
        }
      }
      
      // 3. Filter by Gender
      bool filterGenderClientSide = false;
      if (genders != null && genders.isNotEmpty) {
        if (!usedWhereIn) {
           query = query.where('gender', whereIn: genders.map((e) => e.name).toList());
           usedWhereIn = true;
        } else {
           filterGenderClientSide = true;
        }
      }

      // Execute Query
      final snapshot = await query.limit(limit).get();
      var results = snapshot.docs.map((doc) => DogModel.fromFirestore(doc)).toList();

      // Client-Side Filtering Fallbacks
      if (filterSizeClientSide) {
         results = results.where((dog) => sizes!.contains(dog.size)).toList();
      }

      if (filterGenderClientSide) {
         results = results.where((dog) => genders!.contains(dog.gender)).toList();
      }

      // Breed Filter (Partial Match / Contains)
      if (breedQuery != null && breedQuery.isNotEmpty) {
        final q = breedQuery.toLowerCase();
        results = results.where((dog) => dog.breed.toLowerCase().contains(q)).toList();
      }

      // Sterilized filter
      if (isSterilized != null) {
        results = results.where((dog) => dog.isSterilized == isSterilized).toList();
      }

      return results;
    } catch (e) {
      print('Error searching dogs: $e');
      rethrow;
    }
  }
}
