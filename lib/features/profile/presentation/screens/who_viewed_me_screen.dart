import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../../data/visitor_service.dart';
import '../../../subscriptions/presentation/screens/paywall_screen.dart';

class WhoViewedMeScreen extends ConsumerStatefulWidget {
  const WhoViewedMeScreen({super.key});

  @override
  ConsumerState<WhoViewedMeScreen> createState() => _WhoViewedMeScreenState();
}

class _WhoViewedMeScreenState extends ConsumerState<WhoViewedMeScreen> {
  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authServiceProvider).currentUser;
    final userProfileAsync = ref.watch(currentUserProfileProvider);
    final isPremium = userProfileAsync.value?.isPremium ?? false;

    if (currentUser == null) return const SizedBox.shrink();

    final visitorsStream = ref.watch(visitorServiceProvider).getVisitorsStream(currentUser.uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visite al Profilo'),
      ),
      body: StreamBuilder<List<VisitorModel>>(
        stream: visitorsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.visibility_off, size: 64, color: Colors.grey[400]),
                   const SizedBox(height: 16),
                   Text(
                     'Nessuna visita recente',
                     style: TextStyle(color: Colors.grey[600], fontSize: 16),
                   ),
                ],
              ),
            );
          }

          final visitors = snapshot.data!;

          return Stack(
            children: [
              ListView.builder(
                itemCount: visitors.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final visitor = visitors[index];
                  return _VisitorTile(
                    visitor: visitor, 
                    isPremium: isPremium,
                  );
                },
              ),
              
              if (!isPremium && visitors.isNotEmpty)
                Positioned(
                  bottom: 24,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                         BoxShadow(
                           color: AppColors.primary.withOpacity(0.4),
                           blurRadius: 10,
                           offset: const Offset(0, 4),
                         ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock, color: Colors.white),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Chi ti sta guardando?',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Passa a Premium per vedere i nomi',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                             Navigator.push(
                               context, 
                               MaterialPageRoute(
            settings: const RouteSettings(name: 'paywall'),builder: (_) => const PaywallScreen())
                             );
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                          ),
                          child: const Text('SBLOCCA'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _VisitorTile extends ConsumerWidget {
  final VisitorModel visitor;
  final bool isPremium;

  const _VisitorTile({required this.visitor, required this.isPremium});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If not premium, we blur user details
    final blur = !isPremium;

    return FutureBuilder<UserModel?>(
      future: ref.read(userServiceProvider).getUserById(visitor.visitorId),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null && snapshot.connectionState != ConnectionState.waiting) {
           return const SizedBox.shrink(); // User not found
        }
        
        // Placeholder or actual data
        final name = user?.fullName ?? 'Utente';
        final photoUrl = user?.photoUrl;
        final timeAgo = _formatTime(visitor.lastVisit);

        return Card(
           margin: const EdgeInsets.only(bottom: 12),
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
           child: ListTile(
             contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
             leading: ClipOval(
               child: SizedBox(
                 width: 50,
                 height: 50,
                 child: Stack(
                   fit: StackFit.expand,
                   children: [
                     if (photoUrl != null)
                        Image.network(photoUrl, fit: BoxFit.cover)
                     else
                        Container(color: Colors.grey[300], child: const Icon(Icons.person)),
                     
                     if (blur)
                        BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                          child: Container(color: Colors.black.withOpacity(0.1)),
                        ),
                   ],
                 ),
               ),
             ),
             title: blur 
                 ? Text('Utente Segreto', style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic))
                 : Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
             subtitle: Text('Ha visitato il tuo profilo $timeAgo'),
             trailing: blur 
                  ? const Icon(Icons.lock, color: Colors.amber, size: 20)
                  : null,
             onTap: blur ? () {
                 Navigator.push(context, MaterialPageRoute(
            settings: const RouteSettings(name: 'paywall'),builder: (_) => const PaywallScreen()));
             } : () {
                 // Show profile?
                 // For now just null or maybe show profile bottom sheet
             },
           ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'adesso';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m fa';
    if (diff.inHours < 24) return '${diff.inHours}h fa';
    return DateFormat('dd/MM').format(time);
  }
}
