import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:the_walking_pet/core/services/walk_tracker_service.dart';
import 'package:the_walking_pet/features/walking/presentation/screens/walk_summary_screen.dart';

class ActiveWalkScreen extends ConsumerStatefulWidget {
  static const routeName = 'active-walk';
  final List<String> petIds;

  const ActiveWalkScreen({super.key, this.petIds = const []});

  @override
  ConsumerState<ActiveWalkScreen> createState() => _ActiveWalkScreenState();
}

class _ActiveWalkScreenState extends ConsumerState<ActiveWalkScreen> {
  final MapController _mapController = MapController();
  // Timer per visualizzare il tempo trascorso (UI only)
  Timer? _uiTimer;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Show prominent disclosure before requesting background location
      // (required by Google Play policy for background location access)
      final shouldProceed = await _showLocationDisclosureIfNeeded();
      if (shouldProceed && mounted) {
        await ref.read(walkSessionProvider.notifier).startWalk();
        _startTimer();
      } else if (mounted) {
        // User declined → go back
        Navigator.of(context).pop();
      }
    });
  }

  /// Shows a prominent in-app disclosure explaining WHY background location
  /// is needed, BEFORE the system permission dialog appears.
  /// Returns true if user accepts, false if they decline.
  Future<bool> _showLocationDisclosureIfNeeded() async {
    // Check if location permission is already granted (skip disclosure)
    final status = await bg.BackgroundGeolocation.providerState;
    if (status.status == bg.ProviderChangeEvent.AUTHORIZATION_STATUS_ALWAYS) {
      return true; // Already granted "Always" — no need to show again
    }

    if (!mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Color(0xFFFF6B4A), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Accesso alla posizione',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DOGZN raccoglie i dati sulla posizione per consentire il tracciamento del percorso e il calcolo della distanza e dei passi anche quando l\'app è chiusa o non in uso.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            SizedBox(height: 16),
            Text(
              'Questi dati vengono utilizzati in background esclusivamente per:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            _DisclosureBullet(text: 'Registrare il tracciato della passeggiata sulla mappa'),
            _DisclosureBullet(text: 'Calcolare la distanza complessiva percorsa'),
            _DisclosureBullet(text: 'Continuare il tracciamento in background a schermo spento'),
            SizedBox(height: 16),
            Text(
              'Per abilitare questa funzionalità, nella schermata successiva è necessario selezionare l\'autorizzazione di accesso alla posizione "Consenti sempre".',
              style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Non ora',
              style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B4A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Consenti', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _startTimer() {
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          final startTime = ref.read(walkSessionProvider).startTime;
          if (startTime != null) {
            _duration = DateTime.now().difference(startTime);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    super.dispose();
  }

  Future<void> _finishWalk() async {
    _uiTimer?.cancel();
    await ref.read(walkSessionProvider.notifier).stopWalk();
    if (mounted) {
      // Naviga al riepilogo
       Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            settings: const RouteSettings(name: 'walk_summary'),builder: (_) => WalkSummaryScreen(petIds: widget.petIds)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final walkState = ref.watch(walkSessionProvider);
    final points = walkState.routePoints;
    
    // Centra mappa sull'ultima posizione se disponibile
    if (points.isNotEmpty) {
      // Debounce o check per non muovere troppo la mappa se l'utente la sta toccando
      // Per semplicità ora muoviamo sempre
      _mapController.move(points.last, 17.0);
    }

    return Scaffold(
      body: Stack(
        children: [
          // MAPPA SFONDO
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(41.9028, 12.4964), // Roma Default (will be updated by controller)
              initialZoom: 15.0,
              interactionOptions: const InteractionOptions(
                 flags: InteractiveFlag.all & ~InteractiveFlag.rotate, 
              ),
              onMapReady: () async {
                  // Center on current walk points if available, otherwise get a quick fix
                  try {
                    final currentPoints = ref.read(walkSessionProvider).routePoints;
                    if (currentPoints.isNotEmpty) {
                      _mapController.move(currentPoints.last, 16.0);
                    }
                  } catch (_) {}
              },
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
                    color: Colors.blueAccent,
                  ),
                ],
              ),
              // Marker Posizione Corrente
              if (points.isNotEmpty)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: points.last,
                      width: 60,
                      height: 60,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.blueAccent, width: 3),
                          boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black26)],
                        ),
                        child: const Icon(Icons.pets, color: Colors.orange, size: 30), 
                      ),
                    ),
                  ],
                ),
            ],
          ),

          if (points.isEmpty)
             Positioned(
               bottom: 120, left: 0, right: 0,
               child: Center(
                 child: Container(
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                   decoration: BoxDecoration(
                     color: Colors.black54,
                     borderRadius: BorderRadius.circular(20),
                   ),
                   child: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: const [
                       SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                       SizedBox(width: 8),
                       Text('Ricerca segnale GPS...', style: TextStyle(color: Colors.white, fontSize: 12)),
                     ],
                   ),
                 ),
               ),
             ),

          // OVERLAY TOP (Stats)
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [BoxShadow(blurRadius: 20, color: Colors.black12, offset: Offset(0, 10))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    label: 'TEMPO',
                    value: _formatDuration(_duration),
                    icon: Icons.timer_outlined,
                    color: Colors.orange,
                  ),
                  Container(width: 1, height: 40, color: Colors.grey[200]),
                  _StatItem(
                    label: 'DISTANZA',
                    value: '${walkState.distanceKm.toStringAsFixed(2)} km',
                    icon: Icons.map_outlined,
                    color: Colors.blue,
                  ),
                ],
              ),
            ),
          ),

          // BOTTOM CONTROL
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: SafeArea(
              child: Row(
                children: [
                   // Bottone Pausa/Resume (Piccolo)
                   FloatingActionButton(
                     heroTag: 'pause',
                     backgroundColor: Colors.white,
                     foregroundColor: Colors.black87,
                     onPressed: () {
                        if (walkState.status == WalkStatus.active) {
                          ref.read(walkSessionProvider.notifier).pauseWalk();
                          _uiTimer?.cancel();
                        } else {
                          ref.read(walkSessionProvider.notifier).resumeWalk();
                          _startTimer();
                        }
                     },
                     child: Icon(walkState.status == WalkStatus.active ? Icons.pause_rounded : Icons.play_arrow_rounded),
                   ),
                   const SizedBox(width: 20),
                   // Slider to Finish (o bottone long press per sicurezza)
                   Expanded(
                     child: ElevatedButton(
                        onPressed: _finishWalk,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          elevation: 5,
                        ),
                        child: const Text('TERMINA', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1.2)),
                     ),
                   ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.black87)),
      ],
    );
  }
}

/// Bullet point widget for the location disclosure dialog.
class _DisclosureBullet extends StatelessWidget {
  final String text;
  const _DisclosureBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFFF6B4A))),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4))),
        ],
      ),
    );
  }
}
