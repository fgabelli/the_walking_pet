import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/completed_walk_model.dart';
import 'analytics_service.dart';

final completedWalkServiceProvider = Provider<CompletedWalkService>((ref) => CompletedWalkService());

class WalkStats {
  final int totalWalks;
  final double totalDistanceKm;
  final int totalSteps;
  final int totalCalories;
  final int totalDurationMinutes;
  final double avgDistanceKm;
  final double avgDurationMinutes;

  WalkStats({
    required this.totalWalks,
    required this.totalDistanceKm,
    required this.totalSteps,
    required this.totalCalories,
    required this.totalDurationMinutes,
    required this.avgDistanceKm,
    required this.avgDurationMinutes,
  });

  factory WalkStats.empty() {
    return WalkStats(
      totalWalks: 0,
      totalDistanceKm: 0,
      totalSteps: 0,
      totalCalories: 0,
      totalDurationMinutes: 0,
      avgDistanceKm: 0,
      avgDurationMinutes: 0,
    );
  }

  factory WalkStats.fromWalks(List<CompletedWalkModel> walks) {
    if (walks.isEmpty) return WalkStats.empty();

    final totalDist = walks.fold<double>(0, (sum, w) => sum + w.distanceKm);
    final totalSteps = walks.fold<int>(0, (sum, w) => sum + w.steps);
    final totalCals = walks.fold<int>(0, (sum, w) => sum + w.caloriesBurned);
    final totalDur = walks.fold<int>(0, (sum, w) => sum + w.durationMinutes);

    return WalkStats(
      totalWalks: walks.length,
      totalDistanceKm: totalDist,
      totalSteps: totalSteps,
      totalCalories: totalCals,
      totalDurationMinutes: totalDur,
      avgDistanceKm: totalDist / walks.length,
      avgDurationMinutes: totalDur / walks.length,
    );
  }
}

class CompletedWalkService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Save a completed walk
  Future<String> saveCompletedWalk(CompletedWalkModel walk) async {
    final docRef = await _firestore.collection('completed_walks').add(walk.toFirestore());
    await AnalyticsService.passeggiataCompletata(
      durataMin: walk.durationMinutes,
      distanzaKm: walk.distanceKm,
      passi: walk.steps,
    );
    return docRef.id;
  }

  /// Get user's completed walks stream
  Stream<List<CompletedWalkModel>> getUserWalksStream(String userId) {
    return _firestore
        .collection('completed_walks')
        .where('userId', isEqualTo: userId)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => CompletedWalkModel.fromFirestore(doc)).toList());
  }

  /// Get walks for a specific period
  Future<List<CompletedWalkModel>> getWalksInPeriod(
      String userId, DateTime start, DateTime end) async {
    final snapshot = await _firestore
        .collection('completed_walks')
        .where('userId', isEqualTo: userId)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('startTime', descending: true)
        .get();

    return snapshot.docs.map((doc) => CompletedWalkModel.fromFirestore(doc)).toList();
  }

  /// Get weekly stats (current week Mon-Sun)
  Future<WalkStats> getWeeklyStats(String userId) async {
    final now = DateTime.now();
    final weekday = now.weekday; // 1 = Monday
    final startOfWeek = DateTime(now.year, now.month, now.day - (weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    final walks = await getWalksInPeriod(userId, startOfWeek, endOfWeek);
    return WalkStats.fromWalks(walks);
  }

  /// Get monthly stats (current month)
  Future<WalkStats> getMonthlyStats(String userId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final walks = await getWalksInPeriod(userId, startOfMonth, endOfMonth);
    return WalkStats.fromWalks(walks);
  }

  /// Get all-time stats
  Future<WalkStats> getAllTimeStats(String userId) async {
    final snapshot = await _firestore
        .collection('completed_walks')
        .where('userId', isEqualTo: userId)
        .get();

    final walks = snapshot.docs.map((doc) => CompletedWalkModel.fromFirestore(doc)).toList();
    return WalkStats.fromWalks(walks);
  }

  /// Get daily data for chart (last 7 days)
  Future<List<MapEntry<DateTime, double>>> getDailyDistances(String userId, int days) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day - (days - 1));

    final walks = await getWalksInPeriod(userId, start, now);

    // Group by day
    final Map<String, double> dailyMap = {};
    for (int i = 0; i < days; i++) {
      final day = start.add(Duration(days: i));
      final key = '${day.year}-${day.month}-${day.day}';
      dailyMap[key] = 0;
    }

    for (final walk in walks) {
      final key = '${walk.startTime.year}-${walk.startTime.month}-${walk.startTime.day}';
      dailyMap[key] = (dailyMap[key] ?? 0) + walk.distanceKm;
    }

    return dailyMap.entries
        .map((e) {
          final parts = e.key.split('-');
          return MapEntry(
            DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
            e.value,
          );
        })
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
  }

  /// Get walks that include a specific pet
  Future<List<CompletedWalkModel>> getWalksForPetInPeriod(
      String userId, String petId, DateTime start, DateTime end) async {
    final walks = await getWalksInPeriod(userId, start, end);
    return walks.where((w) => w.petIds.contains(petId)).toList();
  }

  /// Get weekly stats for a specific pet (current week)
  Future<WalkStats> getWeeklyStatsForPet(String userId, String petId) async {
    final now = DateTime.now();
    final weekday = now.weekday;
    final startOfWeek = DateTime(now.year, now.month, now.day - (weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    final walks = await getWalksForPetInPeriod(userId, petId, startOfWeek, endOfWeek);
    return WalkStats.fromWalks(walks);
  }

  /// Get previous week stats for a specific pet (for comparison)
  Future<WalkStats> getPreviousWeekStatsForPet(String userId, String petId) async {
    final now = DateTime.now();
    final weekday = now.weekday;
    final startOfThisWeek = DateTime(now.year, now.month, now.day - (weekday - 1));
    final startOfPrevWeek = startOfThisWeek.subtract(const Duration(days: 7));

    final walks = await getWalksForPetInPeriod(userId, petId, startOfPrevWeek, startOfThisWeek);
    return WalkStats.fromWalks(walks);
  }

  /// Count active days (days with at least one walk) for a pet in current week
  Future<int> getActiveDaysThisWeek(String userId, String petId) async {
    final now = DateTime.now();
    final weekday = now.weekday;
    final startOfWeek = DateTime(now.year, now.month, now.day - (weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    final walks = await getWalksForPetInPeriod(userId, petId, startOfWeek, endOfWeek);
    final uniqueDays = walks.map((w) => '${w.startTime.year}-${w.startTime.month}-${w.startTime.day}').toSet();
    return uniqueDays.length;
  }
}
