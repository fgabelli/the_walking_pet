import 'dart:math';
import '../data/breeds_data.dart';
import '../../shared/models/dog_model.dart';

/// Validates and normalizes breed names using fuzzy matching.
/// - Exact match → use it
/// - Close match (typo) → auto-correct to nearest real breed
/// - No match → default to "Meticcio / Incrocio" (dogs) or "Meticcio / Europeo (Comune)" (cats)
class BreedValidator {
  /// Maximum Levenshtein distance ratio to consider a fuzzy match.
  /// 0.4 = up to 40% of characters can differ (fairly lenient for short breed names).
  static const double _maxDistanceRatio = 0.4;

  /// Validates and corrects a breed name.
  /// Returns the corrected breed name.
  static String validate(String input, PetSpecies species) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return _defaultBreed(species);
    }

    final breeds = species == PetSpecies.dog
        ? BreedsData.dogBreeds
        : BreedsData.catBreeds;

    // 1. Exact match (case-insensitive)
    for (final breed in breeds) {
      if (breed.toLowerCase() == trimmed.toLowerCase()) {
        // "Altro" should map to meticcio
        if (breed == 'Altro') return _defaultBreed(species);
        return breed;
      }
    }

    // 2. Contains match — check if input is contained in a breed name or vice versa
    for (final breed in breeds) {
      if (breed == 'Altro') continue;
      final breedLower = breed.toLowerCase();
      final inputLower = trimmed.toLowerCase();
      if (breedLower.contains(inputLower) || inputLower.contains(breedLower)) {
        return breed;
      }
    }

    // 3. Fuzzy match — find the closest breed using Levenshtein distance
    String? bestMatch;
    double bestScore = double.infinity;

    for (final breed in breeds) {
      if (breed == 'Altro') continue;

      // Compare against the full breed name and also individual words
      final inputLower = trimmed.toLowerCase();
      final breedLower = breed.toLowerCase();

      final distance = _levenshteinDistance(inputLower, breedLower);
      final maxLen = max(inputLower.length, breedLower.length);
      final ratio = maxLen > 0 ? distance / maxLen : 1.0;

      if (ratio < bestScore) {
        bestScore = ratio;
        bestMatch = breed;
      }

      // Also try matching against individual words in the breed name
      final breedWords = breedLower.split(RegExp(r'[\s/()]+'));
      for (final word in breedWords) {
        if (word.length < 3) continue; // Skip short words like "di", "del"
        final wordDistance = _levenshteinDistance(inputLower, word);
        final wordMaxLen = max(inputLower.length, word.length);
        final wordRatio = wordMaxLen > 0 ? wordDistance / wordMaxLen : 1.0;

        if (wordRatio < bestScore) {
          bestScore = wordRatio;
          bestMatch = breed;
        }
      }
    }

    // Accept fuzzy match only if score is good enough
    if (bestMatch != null && bestScore <= _maxDistanceRatio) {
      return bestMatch;
    }

    // 4. No match found → default to Meticcio
    return _defaultBreed(species);
  }

  /// Returns the default breed for the species
  static String _defaultBreed(PetSpecies species) {
    return species == PetSpecies.dog
        ? 'Meticcio / Incrocio'
        : 'Meticcio / Europeo (Comune)';
  }

  /// Checks if a breed is in the valid list (exact match, case-insensitive)
  static bool isValid(String breed, PetSpecies species) {
    final breeds = species == PetSpecies.dog
        ? BreedsData.dogBreeds
        : BreedsData.catBreeds;

    return breeds.any((b) => b.toLowerCase() == breed.toLowerCase());
  }

  /// Classic Levenshtein distance algorithm
  static int _levenshteinDistance(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    // Use two rows instead of full matrix for memory efficiency
    List<int> previousRow = List<int>.generate(t.length + 1, (i) => i);
    List<int> currentRow = List<int>.filled(t.length + 1, 0);

    for (int i = 1; i <= s.length; i++) {
      currentRow[0] = i;

      for (int j = 1; j <= t.length; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        currentRow[j] = [
          currentRow[j - 1] + 1,     // insertion
          previousRow[j] + 1,         // deletion
          previousRow[j - 1] + cost,  // substitution
        ].reduce(min);
      }

      // Swap rows
      final temp = previousRow;
      previousRow = currentRow;
      currentRow = temp;
    }

    return previousRow[t.length];
  }
}
