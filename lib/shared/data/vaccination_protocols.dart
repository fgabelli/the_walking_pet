import '../models/dog_model.dart';

/// Vaccination protocol data for dogs and cats.
/// Based on Italian veterinary guidelines (linee guida WSAVA / ANMVI).
class VaccinationProtocol {
  final String name;
  final String description;
  final int boosterIntervalDays;
  final bool isCore; // Obbligatorio vs consigliato

  const VaccinationProtocol({
    required this.name,
    required this.description,
    required this.boosterIntervalDays,
    required this.isCore,
  });
}

class VaccinationProtocols {
  static const List<VaccinationProtocol> dogVaccines = [
    VaccinationProtocol(
      name: 'Esavalente (CHP + PL)',
      description: 'Cimurro, Epatite, Parvovirosi, Parainfluenza, Leptospirosi',
      boosterIntervalDays: 365,
      isCore: true,
    ),
    VaccinationProtocol(
      name: 'Rabbia',
      description: 'Vaccinazione antirabbica',
      boosterIntervalDays: 365,
      isCore: true,
    ),
    VaccinationProtocol(
      name: 'Leptospirosi',
      description: 'Richiamo singolo leptospirosi',
      boosterIntervalDays: 365,
      isCore: true,
    ),
    VaccinationProtocol(
      name: 'Leishmaniosi',
      description: 'Vaccino contro la leishmaniosi canina',
      boosterIntervalDays: 365,
      isCore: false,
    ),
    VaccinationProtocol(
      name: 'Tosse dei canili (Bordetella)',
      description: 'Bordetella bronchiseptica + Parainfluenza',
      boosterIntervalDays: 365,
      isCore: false,
    ),
    VaccinationProtocol(
      name: 'Piroplasmosi',
      description: 'Babesia canis',
      boosterIntervalDays: 365,
      isCore: false,
    ),
  ];

  static const List<VaccinationProtocol> catVaccines = [
    VaccinationProtocol(
      name: 'Trivalente (RCP)',
      description: 'Panleucopenia, Calicivirus, Herpesvirus felino',
      boosterIntervalDays: 365,
      isCore: true,
    ),
    VaccinationProtocol(
      name: 'Rabbia',
      description: 'Vaccinazione antirabbica',
      boosterIntervalDays: 365,
      isCore: true,
    ),
    VaccinationProtocol(
      name: 'FeLV (Leucemia Felina)',
      description: 'Virus della leucemia felina',
      boosterIntervalDays: 365,
      isCore: false,
    ),
    VaccinationProtocol(
      name: 'FIV (Immunodeficienza Felina)',
      description: 'Virus dell\'immunodeficienza felina',
      boosterIntervalDays: 365,
      isCore: false,
    ),
    VaccinationProtocol(
      name: 'Clamidiosi',
      description: 'Chlamydophila felis',
      boosterIntervalDays: 365,
      isCore: false,
    ),
  ];

  /// Get vaccines for a specific species
  static List<VaccinationProtocol> forSpecies(PetSpecies species) {
    switch (species) {
      case PetSpecies.dog:
        return dogVaccines;
      case PetSpecies.cat:
        return catVaccines;
    }
  }
}
