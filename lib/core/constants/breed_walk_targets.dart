/// Recommended daily walk minutes by breed size and energy level.
/// Returns {minMinutes, maxMinutes} per day.
class BreedWalkTarget {
  final int minMinutesPerDay;
  final int maxMinutesPerDay;

  const BreedWalkTarget(this.minMinutesPerDay, this.maxMinutesPerDay);

  /// Get target based on pet size and energy level (1-5)
  static BreedWalkTarget forPet({
    required String size, // small, medium, large, giant
    required int energyLevel, // 1-5
    required int age, // years
  }) {
    // Senior pets (8+ years) need less
    final seniorFactor = age >= 8 ? 0.7 : (age >= 6 ? 0.85 : 1.0);
    
    int baseMin;
    int baseMax;

    // Base ranges by size
    switch (size.toLowerCase()) {
      case 'small':
      case 'piccola':
        baseMin = 20;
        baseMax = 40;
        break;
      case 'medium':
      case 'media':
        baseMin = 30;
        baseMax = 60;
        break;
      case 'large':
      case 'grande':
        baseMin = 45;
        baseMax = 90;
        break;
      case 'giant':
      case 'gigante':
        baseMin = 40;
        baseMax = 80;
        break;
      default:
        baseMin = 30;
        baseMax = 60;
    }

    // Adjust by energy level (1-5)
    final energyMultiplier = 0.6 + (energyLevel * 0.16); // 0.76 to 1.4

    return BreedWalkTarget(
      (baseMin * energyMultiplier * seniorFactor).round(),
      (baseMax * energyMultiplier * seniorFactor).round(),
    );
  }

  /// Weekly target in minutes
  int get weeklyMinMinutes => minMinutesPerDay * 7;
  int get weeklyMaxMinutes => maxMinutesPerDay * 7;

  /// Check if weekly minutes are in range
  String getVerdict(int weeklyMinutes) {
    if (weeklyMinutes >= weeklyMaxMinutes) return 'above';
    if (weeklyMinutes >= weeklyMinMinutes) return 'in_range';
    return 'below';
  }

  /// Human-readable daily range
  String get dailyRangeLabel => '$minMinutesPerDay-$maxMinutesPerDay min/giorno';
}
