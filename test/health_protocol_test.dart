import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_walking_pet/core/providers/ad_readiness_provider.dart';
import 'package:the_walking_pet/shared/models/dog_model.dart';
import 'package:the_walking_pet/shared/models/health_record_model.dart';
import 'package:the_walking_pet/features/health_record/data/services/health_record_pdf_service.dart';

void main() {
  group('HealthRecordModel tests', () {
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
