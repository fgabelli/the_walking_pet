import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_walking_pet/core/providers/ad_readiness_provider.dart';
import 'package:the_walking_pet/core/services/health_service.dart';
import 'package:the_walking_pet/shared/models/dog_model.dart';
import 'package:the_walking_pet/shared/models/health_record_model.dart';
import 'package:the_walking_pet/features/health_record/data/services/health_record_pdf_service.dart';

void main() {
  group('DogModel tests', () {
    test('copyWith and defaults include veterinarianBusinessId and reminder14dSent', () {
      final now = DateTime(2026, 9, 26);
      final record = HealthRecordModel(
        id: 'rec-1',
        petId: 'dog-1',
        type: HealthRecordType.vaccine,
        title: '1° Vaccino Core',
        date: now,
        nextDueDate: now.add(const Duration(days: 21)),
        veterinarianName: 'Clinica San Francesco',
        veterinarianBusinessId: 'vet-place-123',
        reminder14dSent: false,
      );

      expect(record.veterinarianBusinessId, 'vet-place-123');
      expect(record.reminder14dSent, isFalse);
      expect(record.isCompleted, isTrue);

      final updated = record.copyWith(
        reminder14dSent: true,
        veterinarianBusinessId: 'vet-place-456',
        isCompleted: false,
      );

      expect(updated.reminder14dSent, isTrue);
      expect(updated.veterinarianBusinessId, 'vet-place-456');
      expect(updated.isCompleted, isFalse);
    });

    test('toFirestore includes new fields', () {
      final now = DateTime(2026, 9, 26);
      final record = HealthRecordModel(
        id: 'rec-1',
        petId: 'dog-1',
        type: HealthRecordType.vaccine,
        title: 'Core CEP',
        date: now,
        veterinarianName: 'Dott. Rossi',
        veterinarianBusinessId: 'place_abc',
        reminder14dSent: true,
      );

      final map = record.toFirestore();
      expect(map['veterinarianName'], 'Dott. Rossi');
      expect(map['veterinarianBusinessId'], 'place_abc');
      expect(map['reminder14dSent'], isTrue);
      expect(map['type'], 'vaccine');
    });

    test('DogModel formattedAge calculates puppy weeks, months, or years', () {
      final now = DateTime.now();

      // Cucciolo di 8 settimane
      final puppy = DogModel(
        id: 'p1',
        ownerId: 'u1',
        name: 'Boby',
        breed: 'Labrador',
        age: 0,
        size: DogSize.medium,
        energyLevel: 3,
        character: [],
        createdAt: now,
        birthDate: now.subtract(const Duration(days: 56)),
      );
      expect(puppy.formattedAge, '8 settimane');

      // Cucciolo di 7 mesi
      final dog7m = puppy.copyWith(birthDate: now.subtract(const Duration(days: 215)));
      expect(dog7m.formattedAge, '7 mesi');

      // Cane di 3 anni con birthDate
      final dog3y = puppy.copyWith(birthDate: now.subtract(const Duration(days: 365 * 3 + 10)));
      expect(dog3y.formattedAge, '3 anni');

      // Cane senza birthDate
      DogModel makeDogNoBirth(int age) => DogModel(
        id: 'p0',
        ownerId: 'u1',
        name: 'Boby',
        breed: 'Labrador',
        age: age,
        size: DogSize.medium,
        energyLevel: 3,
        character: [],
        createdAt: now,
      );
      expect(makeDogNoBirth(0).formattedAge, '< 1 anno');
      expect(makeDogNoBirth(1).formattedAge, '1 anno');
      expect(makeDogNoBirth(4).formattedAge, '4 anni');
    });

    test('DogModel toFirestore serializes birthDate and lastVaccinationDate', () {
      final birth = DateTime(2026, 1, 15);
      final lastVac = DateTime(2026, 6, 20);
      final dog = DogModel(
        id: 'd1',
        ownerId: 'u1',
        name: 'Milo',
        breed: 'Beagle',
        age: 0,
        size: DogSize.small,
        energyLevel: 3,
        character: [],
        createdAt: DateTime(2026, 9, 26),
        birthDate: birth,
        lastVaccinationDate: lastVac,
      );

      final map = dog.toFirestore();
      expect(map['birthDate'], Timestamp.fromDate(birth));
      expect(map['lastVaccinationDate'], Timestamp.fromDate(lastVac));
    });
  });

  group('HealthService Protocol Precompilation Rules', () {
    final refDate = DateTime(2026, 9, 26);

    test('Dog without birthDate and without lastVaccinationDate: zero invented dates', () {
      final records = HealthService.calculateRecommendedProtocol(
        petId: 'pet-1',
        age: 3,
        birthDate: null,
        lastVaccinationDate: null,
        referenceDate: refDate,
      );

      expect(records.length, 2, reason: 'Solo 2 richiami adulti');
      // Nessun antiparassitario
      expect(records.any((r) => r['type'] == HealthRecordType.treatment.name), isFalse);

      for (final r in records) {
        expect(r['nextDueDate'], isNull, reason: 'Nessuna data inventata se utente non la fornisce');
        expect(r['reminderEnabled'], isFalse, reason: 'Promemoria disabilitato se data non fornita');
        expect(r['isCompleted'], isFalse);
      }
    });

    test('Dog age=0 but NO birthDate: does NOT generate puppy primary series', () {
      final records = HealthService.calculateRecommendedProtocol(
        petId: 'pet-puppy-nodate',
        age: 0,
        birthDate: null,
        lastVaccinationDate: null,
        referenceDate: refDate,
      );

      expect(records.length, 2, reason: 'Senza data nascita non si ipotizza il ciclo cucciolo');
      for (final r in records) {
        expect(r['nextDueDate'], isNull);
        expect(r['reminderEnabled'], isFalse);
      }
    });

    test('Puppy < 16 weeks with birthDate generates primary series strictly from birthDate', () {
      // Cucciolo nato 6 settimane fa (42 giorni fa)
      final birth = refDate.subtract(const Duration(days: 42));
      final records = HealthService.calculateRecommendedProtocol(
        petId: 'pet-puppy',
        age: 0,
        birthDate: birth,
        lastVaccinationDate: null,
        referenceDate: refDate,
      );

      expect(records.length, 3, reason: '3 dosi primovaccinali del cucciolo');
      expect(records.any((r) => r['type'] == HealthRecordType.treatment.name), isFalse);

      // Dose 1: a 49 giorni dalla nascita (tra 7 giorni)
      final d1 = records[0];
      expect(d1['title'], contains('1° Vaccino Core'));
      expect(d1['date'], Timestamp.fromDate(birth.add(const Duration(days: 49))));
      expect(d1['nextDueDate'], Timestamp.fromDate(birth.add(const Duration(days: 49))));
      expect(d1['reminderEnabled'], isTrue);
      expect(d1['isCompleted'], isFalse);

      // Dose 2: a 70 giorni dalla nascita
      final d2 = records[1];
      expect(d2['title'], contains('2° Richiamo Core'));
      expect(d2['nextDueDate'], Timestamp.fromDate(birth.add(const Duration(days: 70))));
      expect(d2['reminderEnabled'], isTrue);

      // Dose 3: a 98 giorni dalla nascita
      final d3 = records[2];
      expect(d3['title'], contains('3° Richiamo Core'));
      expect(d3['nextDueDate'], Timestamp.fromDate(birth.add(const Duration(days: 98))));
      expect(d3['reminderEnabled'], isTrue);
    });

    test('Puppy of 11 weeks: past doses are created with isCompleted: false, nextDueDate: null, da verificare', () {
      // Cucciolo nato 11 settimane fa (77 giorni fa)
      final birth = refDate.subtract(const Duration(days: 77));
      final records = HealthService.calculateRecommendedProtocol(
        petId: 'pet-puppy-11w',
        age: 0,
        birthDate: birth,
        lastVaccinationDate: null,
        referenceDate: refDate,
      );

      expect(records.length, 3);
      // Dose 1 (49d) è passata: NON sappiamo se è stata fatta, isCompleted DEVE essere false!
      expect(records[0]['isCompleted'], isFalse, reason: 'Nessun record può nascere con isCompleted a true');
      expect(records[0]['nextDueDate'], isNull, reason: 'Fuori dai promemoria e banner scaduti');
      expect(records[0]['reminderEnabled'], isFalse);
      expect(records[0]['notes'], contains('Da verificare sul libretto cartaceo'));

      // Dose 2 (70d) è passata
      expect(records[1]['isCompleted'], isFalse, reason: 'Nessun record può nascere con isCompleted a true');
      expect(records[1]['nextDueDate'], isNull);
      expect(records[1]['reminderEnabled'], isFalse);
      expect(records[1]['notes'], contains('Da verificare sul libretto cartaceo'));

      // Dose 3 (98d) è futura (tra 21 giorni)
      expect(records[2]['isCompleted'], isFalse);
      expect(records[2]['nextDueDate'], Timestamp.fromDate(birth.add(const Duration(days: 98))));
      expect(records[2]['reminderEnabled'], isTrue);
    });

    test('Adult with valid lastVaccinationDate calculates annual (365d) and triennial (1095d)', () {
      // Ultimo vaccino 60 giorni fa
      final lastVac = refDate.subtract(const Duration(days: 60));
      final records = HealthService.calculateRecommendedProtocol(
        petId: 'pet-adult',
        age: 3,
        birthDate: null,
        lastVaccinationDate: lastVac,
        referenceDate: refDate,
      );

      expect(records.length, 2);
      expect(records.any((r) => r['type'] == HealthRecordType.treatment.name), isFalse);

      // Annuale
      final annual = records[0];
      final expectedAnnual = lastVac.add(const Duration(days: 365));
      expect(annual['title'], contains('Annuale'));
      expect(annual['date'], Timestamp.fromDate(lastVac));
      expect(annual['nextDueDate'], Timestamp.fromDate(expectedAnnual));
      expect(annual['reminderEnabled'], isTrue);
      expect(annual['isCompleted'], isFalse);

      // Triennale Core
      final triennial = records[1];
      final expectedTriennial = lastVac.add(const Duration(days: 1095));
      expect(triennial['title'], contains('Triennale Core'));
      expect(triennial['date'], Timestamp.fromDate(lastVac));
      expect(triennial['nextDueDate'], Timestamp.fromDate(expectedTriennial));
      expect(triennial['reminderEnabled'], isTrue);
      expect(triennial['isCompleted'], isFalse);
    });

    test('Adult with expired lastVaccinationDate (>365d): annual has no future nextDueDate and isCompleted is false', () {
      // Ultimo vaccino 400 giorni fa
      final lastVac = refDate.subtract(const Duration(days: 400));
      final records = HealthService.calculateRecommendedProtocol(
        petId: 'pet-expired',
        age: 4,
        birthDate: null,
        lastVaccinationDate: lastVac,
        referenceDate: refDate,
      );

      expect(records.length, 2);
      final annual = records[0];
      expect(annual['nextDueDate'], isNull, reason: 'Scadenza passata non deve programmare promemoria futuri');
      expect(annual['reminderEnabled'], isFalse);
      expect(annual['isCompleted'], isFalse, reason: 'Nessun record può nascere con isCompleted a true');

      final triennial = records[1];
      // Triennale (1095 - 400 = 695 giorni futuri)
      expect(triennial['nextDueDate'], isNotNull);
      expect(triennial['reminderEnabled'], isTrue);
      expect(triennial['isCompleted'], isFalse);
    });

    test('Strict Acceptance Criterion: NO record ever has isCompleted == true from precompilation', () {
      final scenarios = [
        HealthService.calculateRecommendedProtocol(petId: '1', age: 0, birthDate: refDate.subtract(const Duration(days: 100)), referenceDate: refDate),
        HealthService.calculateRecommendedProtocol(petId: '2', age: 0, birthDate: refDate.subtract(const Duration(days: 20)), referenceDate: refDate),
        HealthService.calculateRecommendedProtocol(petId: '3', age: 2, lastVaccinationDate: refDate.subtract(const Duration(days: 500)), referenceDate: refDate),
        HealthService.calculateRecommendedProtocol(petId: '4', age: 2, lastVaccinationDate: refDate.subtract(const Duration(days: 30)), referenceDate: refDate),
        HealthService.calculateRecommendedProtocol(petId: '5', age: 2, birthDate: null, lastVaccinationDate: null, referenceDate: refDate),
      ];

      for (final recs in scenarios) {
        for (final r in recs) {
          expect(r['isCompleted'], isFalse, reason: 'Nessun record può nascere con isCompleted a true');
        }
      }
    });
  });

  group('Navigation & Initial Screen tests', () {
    test('activeTabProvider defaults to 1 (Map tab)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initialTab = container.read(activeTabProvider);
      expect(initialTab, 1, reason: 'L\'app deve aprirsi di default sulla Mappa (tab 1)');
    });
  });

  group('HealthRecordPdfService tests', () {
    test('generatePdf builds valid PDF bytes for dog with vaccines', () async {
      final now = DateTime(2026, 9, 26);
      final dog = DogModel(
        id: 'test-dog-id-12345',
        ownerId: 'owner-1',
        name: 'Luna',
        breed: 'Golden Retriever',
        age: 2,
        size: DogSize.large,
        energyLevel: 3,
        character: ['Socievole', 'Giocherellona'],
        createdAt: now,
        gender: DogGender.female,
        species: PetSpecies.dog,
        microchipNumber: '380260000000000',
        weight: 28.5,
        isSterilized: true,
      );

      final records = [
        HealthRecordModel(
          id: 'v1',
          petId: dog.id,
          type: HealthRecordType.vaccine,
          title: 'Richiamo Annuale (Leptospirosi + Tosse Canili)',
          specificName: 'Leptospirosi e Bordetella',
          date: now,
          nextDueDate: now.add(const Duration(days: 365)),
          isCompleted: false,
          veterinarianName: 'Clinica Veterinaria Milano',
        ),
        HealthRecordModel(
          id: 't1',
          petId: dog.id,
          type: HealthRecordType.treatment,
          title: 'Profilassi Antiparassitaria',
          date: now,
          isCompleted: true,
          notes: 'Collare Seresto applicato',
        ),
      ];

      final pdfBytes = await HealthRecordPdfService.generatePdf(
        dog,
        records,
        ownerName: 'Fabio Gabelli',
      );

      expect(pdfBytes, isA<Uint8List>());
      expect(pdfBytes.isNotEmpty, isTrue);
      // PDF documents start with %PDF header
      final header = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(header, '%PDF-');
    });
  });
}
