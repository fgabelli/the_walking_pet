import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/completed_walk_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class WalkStatsScreen extends ConsumerStatefulWidget {
  const WalkStatsScreen({super.key});

  @override
  ConsumerState<WalkStatsScreen> createState() => _WalkStatsScreenState();
}

class _WalkStatsScreenState extends ConsumerState<WalkStatsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  WalkStats? _weeklyStats;
  WalkStats? _monthlyStats;
  WalkStats? _allTimeStats;
  List<MapEntry<DateTime, double>>? _dailyDistances;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStats());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    final service = ref.read(completedWalkServiceProvider);

    try {
      final results = await Future.wait([
        service.getWeeklyStats(user.uid),
        service.getMonthlyStats(user.uid),
        service.getAllTimeStats(user.uid),
        service.getDailyDistances(user.uid, 7),
      ]);

      if (mounted) {
        setState(() {
          _weeklyStats = results[0] as WalkStats;
          _monthlyStats = results[1] as WalkStats;
          _allTimeStats = results[2] as WalkStats;
          _dailyDistances = results[3] as List<MapEntry<DateTime, double>>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Le Tue Statistiche'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textTertiary,
          tabs: const [
            Tab(text: 'Settimana'),
            Tab(text: 'Mese'),
            Tab(text: 'Totale'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStatsTab(_weeklyStats, 'Questa Settimana', showChart: true),
                _buildStatsTab(_monthlyStats, 'Questo Mese'),
                _buildStatsTab(_allTimeStats, 'Da Sempre'),
              ],
            ),
    );
  }

  Widget _buildStatsTab(WalkStats? stats, String periodLabel, {bool showChart = false}) {
    if (stats == null) {
      return const Center(child: Text('Nessun dato disponibile'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period label
          Text(
            periodLabel,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${stats.totalWalks} passeggiate',
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 24),

          // Main stat: Distance
          _buildHeroStat(
            value: stats.totalDistanceKm.toStringAsFixed(1),
            unit: 'km',
            label: 'Distanza totale',
            icon: Icons.route,
            color: AppColors.accent,
          ),
          const SizedBox(height: 20),

          // Chart (only weekly)
          if (showChart && _dailyDistances != null) ...[
            _buildMiniChart(),
            const SizedBox(height: 24),
          ],

          // Stats grid
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.directions_walk,
                  value: _formatSteps(stats.totalSteps),
                  label: 'Passi',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.local_fire_department,
                  value: '${stats.totalCalories}',
                  label: 'Calorie',
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.timer,
                  value: _formatDuration(stats.totalDurationMinutes),
                  label: 'Tempo',
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.speed,
                  value: '${stats.avgDistanceKm.toStringAsFixed(1)} km',
                  label: 'Media/Walk',
                  color: Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Fun fact
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.05),
                  AppColors.accent.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                const Text('🦴', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 8),
                Text(
                  'Hai bruciato ${(stats.totalCalories / 30).ceil()} croccantini!',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Equivalenti a ${(stats.totalDistanceKm / 0.012).round()} scodinzolii 🐾',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat({
    required String value,
    required String unit,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Text(
                  unit,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChart() {
    if (_dailyDistances == null || _dailyDistances!.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxDist = _dailyDistances!.fold<double>(
      0.1,
      (max, e) => e.value > max ? e.value : max,
    );

    const dayNames = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ultimi 7 giorni',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _dailyDistances!.map((entry) {
                final fraction = entry.value / maxDist;
                final dayLabel = dayNames[entry.key.weekday - 1];
                final isToday = entry.key.day == DateTime.now().day &&
                    entry.key.month == DateTime.now().month;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          entry.value > 0
                              ? '${entry.value.toStringAsFixed(1)}'
                              : '',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isToday
                                ? AppColors.accent
                                : AppColors.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          height: (80 * fraction).clamp(4, 80),
                          decoration: BoxDecoration(
                            color: isToday
                                ? AppColors.accent
                                : AppColors.primary.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dayLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                isToday ? FontWeight.w700 : FontWeight.w500,
                            color: isToday
                                ? AppColors.textPrimary
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSteps(int steps) {
    if (steps >= 1000) {
      return '${(steps / 1000).toStringAsFixed(1)}k';
    }
    return '$steps';
  }

  String _formatDuration(int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return '${h}h ${m}m';
    }
    return '${minutes}m';
  }
}
