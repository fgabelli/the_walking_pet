import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/health_record_model.dart';
import '../../shared/models/dog_model.dart';
import 'notification_service.dart';

final healthServiceProvider = Provider<HealthService>((ref) {
  return HealthService(ref.read(notificationServiceProvider));
});

class HealthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService;

  HealthService(this._notificationService);

  CollectionReference get _healthRef => _firestore.collection('health_records');

  Future<void> addHealthRecord(HealthRecordModel record, {String? petName}) async {
    final docRef = await _healthRef.add(record.toFirestore());

    if (record.reminderEnabled && record.nextDueDate != null && petName != null) {
      await _notificationService.scheduleVaccinationReminder(
        healthRecordId: docRef.id,
        petName: petName,
        vaccineName: record.specificName ?? record.title,
        nextDueDate: record.nextDueDate!,
      );
    }
  }

  Future<void> updateHealthRecord(HealthRecordModel record) async {
    await _healthRef.doc(record.id).update(record.toFirestore());
  }

  Future<void> deleteHealthRecord(String recordId) async {
    await _notificationService.cancelVaccinationReminder(recordId);
    await _healthRef.doc(recordId).delete();
  }

  Stream<List<HealthRecordModel>> getHealthRecordsStream(String petId) {
    return _healthRef
        .where('petId', isEqualTo: petId)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      final records = snapshot.docs
          .map((doc) => HealthRecordModel.fromFirestore(doc))
          .toList();
      
      records.sort((a, b) => b.date.compareTo(a.date));
      return records;
    });
  }

  /// Generates initial recommended health protocol records for a newly created dog.
  /// Strictly idempotent: if any record already exists for [dog.id], does nothing.
  Future<void> precompileHealthProtocol(DogModel dog) async {
    if (dog.id.isEmpty) return;

    try {
      // Strict idempotency check: check if any records exist for this pet
      final existing = await _healthRef.where('petId', isEqualTo: dog.id).limit(1).get();
      if (existing.docs.isNotEmpty) {
        return;
      }

      final now = DateTime.now();
      final batch = _firestore.batch();
      const recommendedNote = 'Protocollo raccomandato • Da confermare con il veterinario';

      if (dog.age == 0) {
        // Cucciolo: protocollo primovaccinale
        // 1. Prima dose Core CEP + Lepto (~7-8 settimane)
        final doc1 = _healthRef.doc();
        final date1 = now.add(const Duration(days: 14));
        batch.set(doc1, {
          'petId': dog.id,
          'type': HealthRecordType.vaccine.name,
          'title': '1° Vaccino Core (CEP + Lepto)',
          'specificName': 'Cimurro, Epatite, Parvovirosi, Leptospirosi',
          'date': Timestamp.fromDate(date1),
          'nextDueDate': Timestamp.fromDate(date1),
          'reminderEnabled': true,
          'isCompleted': false,
          'notes': recommendedNote,
        });

        // 2. Secondo richiamo Core CEP + Lepto (~10-11 settimane, 21 giorni dopo)
        final doc2 = _healthRef.doc();
        final date2 = date1.add(const Duration(days: 21));
        batch.set(doc2, {
          'petId': dog.id,
          'type': HealthRecordType.vaccine.name,
          'title': '2° Richiamo Core (CEP + Lepto)',
          'specificName': 'Cimurro, Epatite, Parvovirosi, Leptospirosi',
          'date': Timestamp.fromDate(date2),
          'nextDueDate': Timestamp.fromDate(date2),
          'reminderEnabled': true,
          'isCompleted': false,
          'notes': recommendedNote,
        });

        // 3. Terzo richiamo Core CEP + Lepto + Tosse canili (~14-16 settimane, 28 giorni dopo)
        final doc3 = _healthRef.doc();
        final date3 = date2.add(const Duration(days: 28));
        batch.set(doc3, {
          'petId': dog.id,
          'type': HealthRecordType.vaccine.name,
          'title': '3° Richiamo Core + Tosse dei Canili',
          'specificName': 'CEP + Lepto + Bordetella bronchiseptica',
          'date': Timestamp.fromDate(date3),
          'nextDueDate': Timestamp.fromDate(date3),
          'reminderEnabled': true,
          'isCompleted': false,
          'notes': recommendedNote,
        });
      } else {
        // Adulto: protocollo di mantenimento annuale e triennale
        // 1. Richiamo annuale Leptospirosi e Tosse dei canili (+365 giorni)
        final doc1 = _healthRef.doc();
        final date1 = now.add(const Duration(days: 365));
        batch.set(doc1, {
          'petId': dog.id,
          'type': HealthRecordType.vaccine.name,
          'title': 'Richiamo Annuale (Leptospirosi + Tosse Canili)',
          'specificName': 'Leptospirosi e Bordetella',
          'date': Timestamp.fromDate(date1),
          'nextDueDate': Timestamp.fromDate(date1),
          'reminderEnabled': true,
          'isCompleted': false,
          'notes': recommendedNote,
        });

        // 2. Richiamo triennale Core CEP (+1095 giorni / 3 anni)
        final doc2 = _healthRef.doc();
        final date2 = now.add(const Duration(days: 1095));
        batch.set(doc2, {
          'petId': dog.id,
          'type': HealthRecordType.vaccine.name,
          'title': 'Richiamo Triennale Core (CEP)',
          'specificName': 'Cimurro, Epatite, Parvovirosi',
          'date': Timestamp.fromDate(date2),
          'nextDueDate': Timestamp.fromDate(date2),
          'reminderEnabled': true,
          'isCompleted': false,
          'notes': recommendedNote,
        });

        // 3. Profilassi stagionale Leishmaniosi / Antiparassitari (+180 giorni)
        final doc3 = _healthRef.doc();
        final date3 = now.add(const Duration(days: 180));
        batch.set(doc3, {
          'petId': dog.id,
          'type': HealthRecordType.treatment.name,
          'title': 'Profilassi Antiparassitaria / Leishmaniosi',
          'specificName': 'Collare o spot-on repellente e test annuale',
          'date': Timestamp.fromDate(date3),
          'nextDueDate': Timestamp.fromDate(date3),
          'reminderEnabled': true,
          'isCompleted': false,
          'notes': recommendedNote,
        });
      }

      await batch.commit();
    } catch (e) {
      // Non-blocking: fail gracefully without crashing dog creation
      print('Errore durante la precompilazione del protocollo sanitario: $e');
    }
  }
}
