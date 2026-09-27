import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

  /// Calcola i record raccomandati per il protocollo sanitario.
  /// Metodo statico puro per facilitare unit test e garantire zero date inventate.
  static List<Map<String, dynamic>> calculateRecommendedProtocol({
    required String petId,
    required int age,
    DateTime? birthDate,
    DateTime? lastVaccinationDate,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final List<Map<String, dynamic>> records = [];

    // Protocollo cucciolo: valido solo se birthDate è fornita E il cane ha meno di 16 settimane (112 giorni)
    final bool isPuppy = birthDate != null && now.difference(birthDate).inDays < 16 * 7;

    if (isPuppy) {
      // 1. Prima dose Core CEP + Lepto (~7-8 settimane: birthDate + 49 giorni)
      final d1 = birthDate.add(const Duration(days: 49));
      final bool d1IsPast = !d1.isAfter(now);
      records.add({
        'petId': petId,
        'type': HealthRecordType.vaccine.name,
        'title': '1° Vaccino Core (CEP + Lepto)',
        'specificName': 'Cimurro, Epatite, Parvovirosi, Leptospirosi',
        'date': Timestamp.fromDate(d1),
        'nextDueDate': d1IsPast ? null : Timestamp.fromDate(d1),
        'reminderEnabled': !d1IsPast,
        'isCompleted': false,
        'notes': d1IsPast
            ? 'Dose prevista da calendario in base alla data di nascita. Da verificare sul libretto cartaceo e confermare.'
            : 'Protocollo raccomandato cucciolo (7-8 settimane) - Da confermare con il veterinario',
      });

      // 2. Secondo richiamo Core CEP + Lepto (~10-11 settimane: birthDate + 70 giorni)
      final d2 = birthDate.add(const Duration(days: 70));
      final bool d2IsPast = !d2.isAfter(now);
      records.add({
        'petId': petId,
        'type': HealthRecordType.vaccine.name,
        'title': '2° Richiamo Core (CEP + Lepto)',
        'specificName': 'Cimurro, Epatite, Parvovirosi, Leptospirosi',
        'date': Timestamp.fromDate(d2),
        'nextDueDate': d2IsPast ? null : Timestamp.fromDate(d2),
        'reminderEnabled': !d2IsPast,
        'isCompleted': false,
        'notes': d2IsPast
            ? 'Dose prevista da calendario in base alla data di nascita. Da verificare sul libretto cartaceo e confermare.'
            : 'Protocollo raccomandato cucciolo (10-11 settimane) - Da confermare con il veterinario',
      });

      // 3. Terzo richiamo Core CEP + Lepto + Tosse canili (~14-16 settimane: birthDate + 98 giorni)
      final d3 = birthDate.add(const Duration(days: 98));
      final bool d3IsPast = !d3.isAfter(now);
      records.add({
        'petId': petId,
        'type': HealthRecordType.vaccine.name,
        'title': '3° Richiamo Core + Tosse dei Canili',
        'specificName': 'CEP + Lepto + Bordetella bronchiseptica',
        'date': Timestamp.fromDate(d3),
        'nextDueDate': d3IsPast ? null : Timestamp.fromDate(d3),
        'reminderEnabled': !d3IsPast,
        'isCompleted': false,
        'notes': d3IsPast
            ? 'Dose prevista da calendario in base alla data di nascita. Da verificare sul libretto cartaceo e confermare.'
            : 'Protocollo raccomandato cucciolo (14-16 settimane) - Da confermare con il veterinario',
      });
    } else {
      // Adulto o cucciolo senza birthDate: generare SOLO i due richiami dell'adulto
      if (lastVaccinationDate != null) {
        // Data ultimo vaccino fornita dall'utente:
        // 1. Richiamo annuale: lastVaccinationDate + 365 giorni
        final annualDue = lastVaccinationDate.add(const Duration(days: 365));
        final bool isAnnualFuture = annualDue.isAfter(now);
        records.add({
          'petId': petId,
          'type': HealthRecordType.vaccine.name,
          'title': 'Richiamo Annuale (Leptospirosi + Tosse Canili)',
          'specificName': 'Leptospirosi e Bordetella',
          'date': Timestamp.fromDate(lastVaccinationDate),
          'nextDueDate': isAnnualFuture ? Timestamp.fromDate(annualDue) : null,
          'reminderEnabled': isAnnualFuture,
          'isCompleted': false,
          'notes': isAnnualFuture
              ? 'Richiamo annuale calcolato dall\'ultima vaccinazione - Da confermare con il veterinario'
              : 'Data ultimo vaccino oltre un anno fa. Richiamo annuale da verificare e concordare col veterinario.',
        });

        // 2. Richiamo triennale Core (CEP): lastVaccinationDate + 1095 giorni (3 anni)
        final triennialDue = lastVaccinationDate.add(const Duration(days: 1095));
        final bool isTriennialFuture = triennialDue.isAfter(now);
        records.add({
          'petId': petId,
          'type': HealthRecordType.vaccine.name,
          'title': 'Richiamo Triennale Core (CEP)',
          'specificName': 'Cimurro, Epatite, Parvovirosi',
          'date': Timestamp.fromDate(lastVaccinationDate),
          'nextDueDate': isTriennialFuture ? Timestamp.fromDate(triennialDue) : null,
          'reminderEnabled': isTriennialFuture,
          'isCompleted': false,
          'notes': isTriennialFuture
              ? 'Richiamo triennale calcolato dall\'ultima vaccinazione - Da confermare con il veterinario'
              : 'Data ultimo vaccino oltre 3 anni fa. Richiamo triennale Core da verificare e concordare col veterinario.',
        });
      } else {
        // Nessuna data fornita dall'utente: NESSUNA DATA INVENTATA!
        // nextDueDate nullo, promemoria disabilitato, isCompleted: false.
        const noteNoDate = 'Inserisci la data dell\'ultimo vaccino col veterinario per attivare i promemoria di richiamo.';

        records.add({
          'petId': petId,
          'type': HealthRecordType.vaccine.name,
          'title': 'Richiamo Annuale (Leptospirosi + Tosse Canili)',
          'specificName': 'Leptospirosi e Bordetella',
          'date': Timestamp.fromDate(now),
          'nextDueDate': null,
          'reminderEnabled': false,
          'isCompleted': false,
          'notes': noteNoDate,
        });

        records.add({
          'petId': petId,
          'type': HealthRecordType.vaccine.name,
          'title': 'Richiamo Triennale Core (CEP)',
          'specificName': 'Cimurro, Epatite, Parvovirosi',
          'date': Timestamp.fromDate(now),
          'nextDueDate': null,
          'reminderEnabled': false,
          'isCompleted': false,
          'notes': noteNoDate,
        });
      }
    }

    return records;
  }

  /// Generates initial recommended health protocol records for a newly created dog.
  /// Strictly idempotent: if any record already exists for [dog.id], does nothing.
  /// Strictly adheres to the rule: No nextDueDate is generated unless derived from a user-supplied date.
  Future<void> precompileHealthProtocol(DogModel dog) async {
    if (dog.id.isEmpty) return;

    try {
      // Strict idempotency check: check if any records exist for this pet
      final existing = await _healthRef.where('petId', isEqualTo: dog.id).limit(1).get();
      if (existing.docs.isNotEmpty) {
        return;
      }

      final recordsData = calculateRecommendedProtocol(
        petId: dog.id,
        age: dog.age,
        birthDate: dog.birthDate,
        lastVaccinationDate: dog.lastVaccinationDate,
      );

      final batch = _firestore.batch();
      for (final data in recordsData) {
        final doc = _healthRef.doc();
        batch.set(doc, data);
      }

      await batch.commit();
    } catch (e) {
      // Non-blocking: fail gracefully without crashing dog creation
      debugPrint('Errore durante la precompilazione del protocollo sanitario: $e');
    }
  }
}
