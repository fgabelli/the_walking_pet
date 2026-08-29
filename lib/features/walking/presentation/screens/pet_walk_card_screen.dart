import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/utils/share_content_helper.dart';
import '../../../../core/services/completed_walk_service.dart';
import '../../../../core/constants/breed_walk_targets.dart';
import '../../../../shared/models/dog_model.dart';
import '../../../../shared/models/completed_walk_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';


class PetWalkCardScreen extends ConsumerStatefulWidget {
  final DogModel pet;

  const PetWalkCardScreen({super.key, required this.pet});

  @override
  ConsumerState<PetWalkCardScreen> createState() => _PetWalkCardScreenState();
}

class _PetWalkCardScreenState extends ConsumerState<PetWalkCardScreen> {
  final GlobalKey _cardKey = GlobalKey();
  bool _isLoading = true;
  bool _isSharing = false;
  WalkStats? _thisWeek;
  WalkStats? _lastWeek;
  int _activeDays = 0;
  List<CompletedWalkModel> _recentWalks = [];
  late BreedWalkTarget _target;

  @override
  void initState() {
    super.initState();
    _target = BreedWalkTarget.forPet(
      size: widget.pet.size.name,
      energyLevel: widget.pet.energyLevel,
      age: widget.pet.age,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    final service = ref.read(completedWalkServiceProvider);

    try {
      final results = await Future.wait([
        service.getWeeklyStatsForPet(user.uid, widget.pet.id),
        service.getPreviousWeekStatsForPet(user.uid, widget.pet.id),
        service.getActiveDaysThisWeek(user.uid, widget.pet.id),
        service.getWalksForPetInPeriod(user.uid, widget.pet.id, DateTime.now().subtract(const Duration(days: 30)), DateTime.now()),
      ]);

      if (mounted) {
        setState(() {
          _thisWeek = results[0] as WalkStats;
          _lastWeek = results[1] as WalkStats;
          _activeDays = results[2] as int;
          _recentWalks = results[3] as List<CompletedWalkModel>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading pet walk card: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _shareCard() async {
    try {
      setState(() => _isSharing = true);

      RenderRepaintBoundary boundary =
          _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final tempDir = Directory.systemTemp;
      final file = await File('${tempDir.path}/dogzn_walk_card_${widget.pet.name.toLowerCase()}.png').create();
      await file.writeAsBytes(pngBytes);

      if (mounted) {
        await ShareContentHelper.shareLocalImage(
          context: context,
          imageFile: file,
          caption: 'La settimana di ${widget.pet.name} su Dogzn! 🐾 #Dogzn #WalkCard',
        );
      }
    } catch (e) {
      debugPrint('Share error: $e');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: Text('Statistiche ${widget.pet.name}'),
        actions: [
          IconButton(
            icon: _isSharing
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.grey, strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share),
            onPressed: _isSharing ? null : _shareCard,
            tooltip: 'Condividi',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _logManualWalk(context),
        backgroundColor: const Color(0xFFFF6B4A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Passeggiata', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // HIDDEN WALK CARD FOR IMAGE EXPORT (must be painted, so we move it off-screen)
                Positioned(
                  top: -5000, // Move it far off screen
                  left: 0,
                  right: 0, // Keep the width correct
                  child: RepaintBoundary(
                    key: _cardKey,
                    child: _buildWalkCard(),
                  ),
                ),
                // NEW STRAVA-LIKE DASHBOARD UI
                Positioned.fill(
                  child: _buildStravaDashboard(),
                ),
              ],
            ),
    );
  }

  Widget _buildStravaDashboard() {
    final stats = _thisWeek ?? WalkStats.empty();
    final maxTarget = _target.weeklyMaxMinutes;
    final progress = maxTarget > 0 ? (stats.totalDurationMinutes / maxTarget).clamp(0.0, 1.0) : 0.0;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PROFILE HEADER
          Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Colors.grey[300],
                backgroundImage: widget.pet.photoUrl != null && widget.pet.photoUrl!.isNotEmpty 
                  ? NetworkImage(widget.pet.photoUrl!) 
                  : null,
                child: widget.pet.photoUrl == null || widget.pet.photoUrl!.isEmpty 
                  ? const Icon(Icons.pets, size: 30, color: Colors.white) 
                  : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.pet.name,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0A2342)),
                    ),
                    Text(
                      '${widget.pet.breed} • ${widget.pet.age} anni',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // TARGET AND PROGRESS
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Questa settimana', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0A2342))),
                    Text('${stats.totalDurationMinutes} min', style: const TextStyle(color: Color(0xFFFF6B4A), fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= (_target.weeklyMinMinutes / maxTarget) ? const Color(0xFF4CAF50) : const Color(0xFFFF6B4A),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Obiettivo: ${_target.weeklyMinMinutes}-${_target.weeklyMaxMinutes} min/settimana',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // QUICK STATS
          Row(
            children: [
              Expanded(child: _buildDashStat(Icons.directions_walk, '${stats.totalWalks}', 'Uscite')),
              const SizedBox(width: 12),
              Expanded(child: _buildDashStat(Icons.calendar_today, '$_activeDays/7', 'Giorni attivi')),
              const SizedBox(width: 12),
              Expanded(child: _buildDashStat(Icons.route, stats.totalDistanceKm.toStringAsFixed(1), 'km')),
            ],
          ),
          const SizedBox(height: 32),
          
          // RECENT WALKS (FEED)
          const Text(
            'Ultime attività',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A2342)),
          ),
          const SizedBox(height: 16),
          if (_recentWalks.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Nessuna attività recente registrata.', style: TextStyle(color: Colors.grey[500])),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentWalks.take(10).length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, index) {
                final walk = _recentWalks[index];
                final dateStr = '${walk.startTime.day.toString().padLeft(2, '0')}/${walk.startTime.month.toString().padLeft(2, '0')}';
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[100]!),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFE3F2FD),
                      child: const Icon(Icons.directions_walk, color: Colors.blueAccent),
                    ),
                    title: Text(
                      '$dateStr • ${walk.durationMinutes} min',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A2342)),
                    ),
                    subtitle: Text(
                      '${walk.distanceKm.toStringAsFixed(2)} km  •  ${walk.caloriesBurned} kcal',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 80), // Padding for FAB
        ],
      ),
    );
  }

  Widget _buildDashStat(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.blueGrey[400], size: 24),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A2342))),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      ),
    );
  }

  void _logManualWalk(BuildContext context) {
    int duration = 30;
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Registra Passeggiata'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Aggiungi manualmente i minuti della passeggiata di ${widget.pet.name} senza usare il GPS.'),
                const SizedBox(height: 20),
                const Text('Durata della passeggiata:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Slider(
                  value: duration.toDouble(),
                  min: 5,
                  max: 120,
                  divisions: 23,
                  label: '$duration min',
                  activeColor: const Color(0xFFFF6B4A),
                  onChanged: (val) => setDialogState(() => duration = val.toInt()),
                ),
                Text('$duration minuti', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFFF6B4A))),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B4A), foregroundColor: Colors.white),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _saveManualWalk(duration);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Passeggiata manuale registrata con successo!')),
                    );
                    _loadData(); // Ricarica le statistiche della walk card per includere la nuova!
                  }
                },
                child: const Text('Salva Attività'),
              )
            ],
          );
        }
      ),
    );
  }

  Future<void> _saveManualWalk(int durationMinutes) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    
    final now = DateTime.now();
    // Use an average walking speed of 4km/h for distance estimation
    final distanceKm = (durationMinutes / 60) * 4.0; 
    
    final walk = CompletedWalkModel(
      id: '', // Will be generated by Firestore
      userId: user.uid,
      startTime: now.subtract(Duration(minutes: durationMinutes)),
      endTime: now,
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
      steps: durationMinutes * 80, // Estimate
      caloriesBurned: durationMinutes * 4, // Estimate
      petIds: [widget.pet.id],
    );
    
    await ref.read(completedWalkServiceProvider).saveCompletedWalk(walk);
  }

  Widget _buildWalkCard() {
    final pet = widget.pet;
    final stats = _thisWeek ?? WalkStats.empty();
    final prevStats = _lastWeek ?? WalkStats.empty();
    final verdict = _target.getVerdict(stats.totalDurationMinutes);

    // Comparison deltas
    final durationDelta = stats.totalDurationMinutes - prevStats.totalDurationMinutes;
    final walksDelta = stats.totalWalks - prevStats.totalWalks;

    return Container(
      width: 350,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // HEADER with pet info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0A2342), Color(0xFF1B3A5C)],
              ),
            ),
            child: Row(
              children: [
                // Pet avatar
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                    image: pet.photoUrl != null
                        ? DecorationImage(
                            image: NetworkImage(pet.photoUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: pet.photoUrl == null ? const Color(0xFFFF6B4A) : null,
                  ),
                  child: pet.photoUrl == null
                      ? Center(
                          child: Text(
                            pet.species == PetSpecies.cat ? '🐱' : '🐶',
                            style: const TextStyle(fontSize: 28),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pet.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${pet.breed} · ${pet.age} anni',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Week badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'QUESTA\nSETTIMANA',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // VERDICT BAR
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            color: _verdictColor(verdict),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_verdictEmoji(verdict), style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  _verdictLabel(verdict),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // STATS BODY
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Main stat: minutes
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${stats.totalDurationMinutes}',
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0A2342),
                        height: 1.0,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8, left: 6),
                      child: Text(
                        'min',
                        style: TextStyle(
                          color: Color(0xFFFF6B4A),
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Delta vs last week
                    if (prevStats.totalWalks > 0)
                      _buildDeltaBadge(durationDelta, 'min'),
                  ],
                ),
                const SizedBox(height: 8),
                // Target range
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Target: ${_target.weeklyMinMinutes}-${_target.weeklyMaxMinutes} min/settimana',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Row(
                              children: [
                                Icon(Icons.favorite, color: Colors.redAccent, size: 24),
                                SizedBox(width: 8),
                                Expanded(child: Text('Piano Salute', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Il fabbisogno giornaliero (${_target.dailyRangeLabel}) è calcolato in base all\'età, alla stazza e all\'energia del tuo pet.'),
                                if (widget.pet.weight == null) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    'Consiglio: aggiungi il peso nel profilo di ${widget.pet.name} per un calcolo ancora più accurato!',
                                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                                  ),
                                ]
                              ],
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                            ],
                          ),
                        );
                      },
                      child: Icon(Icons.info_outline, size: 16, color: Colors.grey[400]),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Target range bar
                _buildTargetBar(stats.totalDurationMinutes),
                const SizedBox(height: 24),

                // Stats grid
                Row(
                  children: [
                    _buildMiniStat(
                      icon: Icons.directions_walk,
                      value: '${stats.totalWalks}',
                      label: 'Uscite',
                      delta: walksDelta,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    _buildMiniStat(
                      icon: Icons.calendar_today,
                      value: '$_activeDays/7',
                      label: 'Giorni attivi',
                      color: Colors.purple,
                    ),
                    const SizedBox(width: 12),
                    _buildMiniStat(
                      icon: Icons.route,
                      value: '${stats.totalDistanceKm.toStringAsFixed(1)} km',
                      label: 'Distanza',
                      color: Colors.teal,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Branding footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 24, height: 24,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [Color(0xFFFF6B4A), Color(0xFFFF8A65)]),
                          ),
                          child: const Icon(Icons.pets, color: Colors.white, size: 12),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'DOGZN',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: 2,
                            color: Color(0xFF0A2342),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Walk Card',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetBar(int currentMinutes) {
    final maxTarget = _target.weeklyMaxMinutes;
    final progress = maxTarget > 0 ? (currentMinutes / maxTarget).clamp(0.0, 1.0) : 0.0;
    final minProgress = maxTarget > 0 ? (_target.weeklyMinMinutes / maxTarget).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        const SizedBox(height: 8),
        Stack(
          children: [
            // Background
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // Min target marker
            Positioned(
              left: minProgress * 302, // approximate width
              child: Container(
                width: 2, height: 8,
                color: Colors.grey[400],
              ),
            ),
            // Progress
            FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: progress >= minProgress
                        ? [const Color(0xFF4CAF50), const Color(0xFF66BB6A)]
                        : [const Color(0xFFFF6B4A), const Color(0xFFFF8A65)],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDeltaBadge(int delta, String unit) {
    final isPositive = delta >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (isPositive ? Colors.green : Colors.red).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.arrow_upward : Icons.arrow_downward,
            size: 14,
            color: isPositive ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 4),
          Text(
            '${delta.abs()} $unit',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isPositive ? Colors.green[700] : Colors.red[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    int? delta,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0A2342),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            if (delta != null && delta != 0) ...[
              const SizedBox(height: 4),
              Text(
                '${delta > 0 ? '+' : ''}$delta',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: delta > 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _verdictColor(String verdict) {
    switch (verdict) {
      case 'above':
        return const Color(0xFF4CAF50);
      case 'in_range':
        return const Color(0xFF2196F3);
      case 'below':
      default:
        return const Color(0xFFFF6B4A);
    }
  }

  String _verdictEmoji(String verdict) {
    switch (verdict) {
      case 'above':
        return '🏆';
      case 'in_range':
        return '✅';
      case 'below':
      default:
        return '⚠️';
    }
  }

  String _verdictLabel(String verdict) {
    switch (verdict) {
      case 'above':
        return 'Sopra il target! Campione!';
      case 'in_range':
        return 'Nel range consigliato';
      case 'below':
      default:
        return 'Sotto il target — usciamo di più!';
    }
  }
}
