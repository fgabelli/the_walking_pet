import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../shared/utils/share_content_helper.dart';
import 'package:the_walking_pet/core/services/walk_tracker_service.dart';
import 'package:the_walking_pet/core/services/device_health_service.dart';
import 'package:the_walking_pet/core/services/completed_walk_service.dart';
import 'package:the_walking_pet/shared/models/completed_walk_model.dart';
import 'package:the_walking_pet/core/services/dog_service.dart';
import 'package:the_walking_pet/shared/models/dog_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../nextdoor/presentation/screens/create_announcement_screen.dart';
import 'walk_stats_screen.dart';
import 'pet_walk_card_screen.dart';
import '../../../../core/services/social_feed_service.dart';
import '../../../../shared/models/social_post_model.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

class WalkSummaryScreen extends ConsumerStatefulWidget {
  final List<String> petIds;

  const WalkSummaryScreen({super.key, this.petIds = const []});

  @override
  ConsumerState<WalkSummaryScreen> createState() => _WalkSummaryScreenState();
}

class _WalkSummaryScreenState extends ConsumerState<WalkSummaryScreen> {
  final GlobalKey _cardKey = GlobalKey();
  bool _isSaving = false;
  bool _healthSaved = false;
  bool _healthSaving = Platform.isIOS;
  bool _firestoreSaved = false;
  List<DogModel> _pets = [];
  late String _funnyPhrase;

  @override
  void initState() {
    super.initState();
    _funnyPhrase = _getRandomFunnyPhrase();
    // Auto-save to Health on screen open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Platform.isIOS) _autoSaveToHealth();
      _saveCompletedWalkToFirestore();
      _loadPets();
    });
  }

  Future<void> _loadPets() async {
    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) return;
      final allPets = await DogService().getDogsByOwnerId(user.uid);
      if (mounted) {
        setState(() {
          // If petIds were passed, filter to only those. Otherwise show all.
          if (widget.petIds.isNotEmpty) {
            _pets = allPets.where((p) => widget.petIds.contains(p.id)).toList();
          } else {
            _pets = allPets;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _saveCompletedWalkToFirestore() async {
    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) return;

      final state = ref.read(walkSessionProvider);
      if (state.startTime == null) return;

      final endTime = DateTime.now();
      final duration = endTime.difference(state.startTime!);
      final cals = (state.distanceKm * 50).round();
      // Passi reali dal pedometer, con fallback su stima se sensore non disponibile
      final steps = state.currentSteps > 0 ? state.currentSteps : (state.distanceKm * 1300).round();

      final completedWalk = CompletedWalkModel(
        id: '',
        userId: user.uid,
        startTime: state.startTime!,
        endTime: endTime,
        distanceKm: state.distanceKm,
        durationMinutes: duration.inMinutes,
        steps: steps,
        caloriesBurned: cals,
        petIds: widget.petIds,
      );

      await ref.read(completedWalkServiceProvider).saveCompletedWalk(completedWalk);
      if (mounted) setState(() => _firestoreSaved = true);
    } catch (e) {
      debugPrint('Error saving walk to Firestore: $e');
    }
  }

  Future<void> _autoSaveToHealth() async {
    try {
      final healthService = ref.read(deviceHealthServiceProvider);
      final authorized = await healthService.requestPermissions();
      if (!authorized) {
        setState(() {
          _healthSaving = false;
          _healthSaved = false;
        });
        return;
      }

      final state = ref.read(walkSessionProvider);
      if (state.startTime == null) {
        setState(() {
          _healthSaving = false;
          _healthSaved = false;
        });
        return;
      }

      int cals = (state.distanceKm * 50).round();
      int steps = state.currentSteps > 0 ? state.currentSteps : (state.distanceKm * 1300).round();

      final success = await ref.read(deviceHealthServiceProvider).saveWalkSession(
        startTime: state.startTime!,
        endTime: DateTime.now(),
        steps: steps,
        caloriesBurned: cals,
        distanceMeters: state.distanceKm * 1000,
      );

      if (mounted) {
        setState(() {
          _healthSaving = false;
          _healthSaved = success;
        });
      }
    } catch (e) {
      debugPrint('Auto-save Health error: $e');
      if (mounted) {
        setState(() {
          _healthSaving = false;
          _healthSaved = false;
        });
      }
    }
  }

  Future<void> _shareCard() async {
    try {
      setState(() => _isSaving = true);

      RenderRepaintBoundary boundary =
          _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final tempDir = Directory.systemTemp;
      final file = await File('${tempDir.path}/dogzn_walk_card.png').create();
      await file.writeAsBytes(pngBytes);

      if (mounted) {
        await ShareContentHelper.shareLocalImage(
          context: context,
          imageFile: file,
          caption: 'Passeggiata epica con il mio Pet su Dogzn! 🐾🐕 #Dogzn #DogWalking',
        );
      }
    } catch (e) {
      debugPrint('Errore condivisione: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _shareToFeed(double distanceKm, int treats) async {
    try {
      setState(() => _isSaving = true);
      
      RenderRepaintBoundary boundary =
          _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final tempDir = Directory.systemTemp;
      final file = await File('${tempDir.path}/dogzn_walk_card_feed.png').create();
      await file.writeAsBytes(pngBytes);

      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) throw Exception("User non loggato");
      
      final profile = ref.read(currentUserProfileProvider).value;
      final displayName = profile != null
          ? '${profile.firstName} ${profile.lastName}'.trim()
          : (user.displayName ?? 'Utente');

      final dist = distanceKm.toStringAsFixed(2);
      final post = SocialPostModel(
        id: '',
        authorId: user.uid,
        authorName: displayName,
        authorPhotoUrl: profile?.photoUrl ?? user.photoURL,
        text: 'Abbiamo appena completato una passeggiata di $dist km! 🐾 $treats croccantini bruciati! Chi si unisce la prossima volta?',
        type: PostType.photo,
        createdAt: DateTime.now(),
      );

      await ref.read(socialFeedServiceProvider).createPost(post, imageFile: file);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Condiviso nel Feed Community! 🐾 Lo trovi in Community > Feed')));
      }
    } catch (e) {
      debugPrint('Errore condivisione in bacheca: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// Builds overlapping stacked pet avatars for the Walk Card
  Widget _buildStackedPetAvatars() {
    final maxVisible = 4;
    final visiblePets = _pets.take(maxVisible).toList();
    final extraCount = _pets.length - maxVisible;
    const avatarSize = 38.0;
    const overlap = 14.0;

    final totalWidth = avatarSize + (visiblePets.length - 1) * (avatarSize - overlap) +
        (extraCount > 0 ? (avatarSize - overlap) : 0);

    return SizedBox(
      width: totalWidth,
      height: avatarSize,
      child: Stack(
        children: [
          ...visiblePets.asMap().entries.map((entry) {
            final index = entry.key;
            final pet = entry.value;
            return Positioned(
              right: index * (avatarSize - overlap),
              child: _buildPetAvatar(pet, avatarSize),
            );
          }),
          if (extraCount > 0)
            Positioned(
              right: visiblePets.length * (avatarSize - overlap),
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0A2342),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    '+$extraCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPetAvatar(DogModel pet, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 6,
          ),
        ],
        color: pet.photoUrl == null ? const Color(0xFFFF6B4A) : null,
        image: pet.photoUrl != null
            ? DecorationImage(
                image: NetworkImage(pet.photoUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: pet.photoUrl == null
          ? Center(
              child: Text(
                pet.name.isNotEmpty ? pet.name[0].toUpperCase() : '🐾',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            )
          : null,
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu', 'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatPace(double distanceKm, Duration duration) {
    if (distanceKm <= 0) return '--:--';
    final paceMinutes = duration.inMinutes / distanceKm;
    final mins = paceMinutes.floor();
    final secs = ((paceMinutes - mins) * 60).round();
    return "$mins'${secs.toString().padLeft(2, '0')}\"";
  }

  // --- FUN ELEMENTS ---

  Map<String, String> _getWalkTitle(double km) {
    if (km >= 10) return {'emoji': '🦸', 'title': 'Ultra Runner Canino!'};
    if (km >= 5) return {'emoji': '🏆', 'title': 'Maratoneta a 4 Zampe!'};
    if (km >= 2) return {'emoji': '🔥', 'title': 'Esploratore Urbano!'};
    if (km >= 0.5) return {'emoji': '🐕', 'title': 'Giro del Quartiere!'};
    return {'emoji': '😴', 'title': 'Passeggiata del Divano'};
  }

  int _caloriesToTreats(int calories) {
    // ~30 kcal per croccantino medio
    return (calories / 30).ceil().clamp(0, 99);
  }

  String _getRandomFunnyPhrase() {
    final phrases = [
      'Il tuo cane ti ha dato 5 stelle su Dogzn ⭐⭐⭐⭐⭐',
      'Il tuo cane ha annusato circa ${30 + Random().nextInt(50)} lampioni oggi 🐽',
      'Coda scodinzolata circa ${200 + Random().nextInt(800)} volte 🐾',
      'Il tuo cane pensa che sei un ottimo umano oggi 🐶',
      'Livello di felicità canina: MASSIMO 🎉',
      'Il tuo cane ti nomina "Umano dell\'Anno" 🏅',
      'Hai guadagnato la fiducia di ${2 + Random().nextInt(5)} gatti di quartiere 🐱',
      'Il tuo cane ha battuto il suo record di scodinzolii 💫',
      'Complimenti! Il tuo cane ora dorme beato 😴💤',
      'Recensione del cane: "Lo rifarei. 12/10" 🐕',
      'Passi umani convertiti in zampettate: ${500 + Random().nextInt(2000)} 🐾',
      'Il tuo cane ha deciso che meriti un extra biscotto 🍪',
    ];
    return phrases[Random().nextInt(phrases.length)];
  }

  @override
  Widget build(BuildContext context) {
    final walkState = ref.watch(walkSessionProvider);
    final points = walkState.routePoints;
    final distanceKm = walkState.distanceKm;
    final duration = walkState.startTime != null
        ? DateTime.now().difference(walkState.startTime!)
        : Duration.zero;
    final calories = (distanceKm * 50).round();
    // Passi reali dal pedometer, con fallback su stima se sensore non disponibile
    final steps = walkState.currentSteps > 0 ? walkState.currentSteps : (distanceKm * 1300).round();
    final walkTitle = _getWalkTitle(distanceKm);
    final treats = _caloriesToTreats(calories);

    LatLngBounds? bounds;
    if (points.isNotEmpty) {
      bounds = LatLngBounds.fromPoints(points);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('Riepilogo Passeggiata'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              ref.read(walkSessionProvider.notifier).reset();
              Navigator.of(context).pop();
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 12),

            // Health auto-save status (iOS only — Health Connect disabled on Android)
            if (Platform.isIOS)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _healthSaving
                      ? Container(
                          key: const ValueKey('saving'),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              SizedBox(width: 10),
                              Text('Salvataggio su Salute...', style: TextStyle(fontSize: 13, color: Colors.blue)),
                            ],
                          ),
                        )
                      : Container(
                          key: const ValueKey('done'),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: _healthSaved ? Colors.green[50] : Colors.orange[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _healthSaved ? Icons.check_circle : Icons.info_outline,
                                size: 18,
                                color: _healthSaved ? Colors.green : Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _healthSaved ? 'Salvato su Salute ✓' : 'Non salvato su Salute',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _healthSaved ? Colors.green[700] : Colors.orange[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),

            const SizedBox(height: 16),

            // INSTAGRAM-READY SHARE CARD
            Center(
              child: RepaintBoundary(
                key: _cardKey,
                child: Container(
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
                      // MAP SECTION (top)
                      SizedBox(
                        height: 260,
                        child: Stack(
                          children: [
                            if (points.isNotEmpty)
                              Positioned.fill(
                                child: FlutterMap(
                                  options: MapOptions(
                                    initialCenter: bounds?.center ?? const LatLng(0, 0),
                                    initialZoom: 14.0,
                                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName: 'com.dogzn.app',
                                    ),
                                    PolylineLayer(
                                      polylines: [
                                        Polyline(
                                          points: points,
                                          strokeWidth: 5.0,
                                          color: const Color(0xFFFF6B4A),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                color: const Color(0xFF1A1A2E),
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.pets, size: 48, color: Colors.white24),
                                      SizedBox(height: 8),
                                      Text("Passeggiata breve", style: TextStyle(color: Colors.white38)),
                                    ],
                                  ),
                                ),
                              ),
                            // Top gradient overlay
                            Positioned(
                              top: 0, left: 0, right: 0, height: 60,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.black.withOpacity(0.3), Colors.transparent],
                                  ),
                                ),
                              ),
                            ),
                            // Bottom gradient overlay
                            Positioned(
                              bottom: 0, left: 0, right: 0, height: 80,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, const Color(0xFF0A2342).withOpacity(0.95)],
                                  ),
                                ),
                              ),
                            ),
                            // Date badge
                            Positioned(
                              top: 16, left: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _formatDate(DateTime.now()),
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                            // Pet photo avatars (stacked)
                            if (_pets.isNotEmpty)
                              Positioned(
                                top: 16, right: 16,
                                child: _buildStackedPetAvatars(),
                              ),
                          ],
                        ),
                      ),

                      // STATS SECTION (bottom - dark branded)
                      Container(
                        color: const Color(0xFF0A2342),
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                        child: Column(
                          children: [
                            // FUN TITLE based on distance
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFFF6B4A).withOpacity(0.2),
                                    const Color(0xFFFF8A65).withOpacity(0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(walkTitle['emoji']!, style: const TextStyle(fontSize: 22)),
                                  const SizedBox(width: 8),
                                  Text(
                                    walkTitle['title']!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Main stat: Distance
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  distanceKm.toStringAsFixed(2),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 52,
                                    fontWeight: FontWeight.w900,
                                    height: 1.0,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 6, left: 6),
                                  child: Text(
                                    'km',
                                    style: TextStyle(
                                      color: Color(0xFFFF6B4A),
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Secondary stats row
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildStatItem(
                                    icon: Icons.timer_outlined,
                                    value: _formatDuration(duration),
                                    label: 'TEMPO',
                                  ),
                                  Container(width: 1, height: 36, color: Colors.white12),
                                  _buildStatItem(
                                    icon: Icons.local_fire_department,
                                    value: '$calories',
                                    label: 'KCAL',
                                  ),
                                  Container(width: 1, height: 36, color: Colors.white12),
                                  _buildStatItem(
                                    icon: Icons.speed,
                                    value: _formatPace(distanceKm, duration),
                                    label: 'PASSO',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // TREATS CONVERTER 🦴
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('🦴', style: TextStyle(fontSize: 18)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Hai bruciato $treats croccantini!',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // FUNNY PHRASE 😂
                            Text(
                              _funnyPhrase,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Pet names
                            if (_pets.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    const Text('🐾 ', style: TextStyle(fontSize: 14)),
                                    Expanded(
                                      child: Text(
                                        'con ${_pets.map((p) => p.name).join(', ')}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Branding footer
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 28, height: 28,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [Color(0xFFFF6B4A), Color(0xFFFF8A65)],
                                        ),
                                      ),
                                      child: const Icon(Icons.pets, color: Colors.white, size: 14),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'DOGZN',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'The Walking Pet',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // SHARE BUTTON
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.share_rounded, size: 22),
                  label: Text(
                    _isSaving ? 'Preparando...' : 'CONDIVIDI SUI SOCIAL',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                  ),
                  onPressed: _isSaving ? null : _shareCard,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B4A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                ),
              ),
            ),

            // INTERNAL SHARE BUTTON
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.pets, size: 22),
                  label: Text(
                    _isSaving ? 'Condivisione...' : 'CONDIVIDI NEL FEED DOGZN',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                  ),
                  onPressed: _isSaving ? null : () => _shareToFeed(distanceKm, treats),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A2342),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // VIEW STATS BUTTON
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.bar_chart_rounded, size: 20),
                  label: const Text(
                    'VEDI LE TUE STATISTICHE',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WalkStatsScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0A2342),
                    side: const BorderSide(color: Color(0xFF0A2342)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // WALK CARD per pet
            if (_pets.isNotEmpty)
              ..._pets.map((pet) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 4),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.credit_card, size: 20),
                    label: Text(
                      'WALK CARD DI ${pet.name.toUpperCase()}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => PetWalkCardScreen(pet: pet)),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF6B4A),
                      side: const BorderSide(color: Color(0xFFFF6B4A)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              )),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({required IconData icon, required String value, required String label}) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFFF6B4A), size: 18),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}
