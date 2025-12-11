import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/walk_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../core/services/user_service.dart';
import '../../../../shared/presentation/widgets/user_profile_bottom_sheet.dart';
import '../providers/walk_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'create_walk_screen.dart';

class WalkDetailScreen extends ConsumerWidget {
  final WalkModel walk;

  const WalkDetailScreen({super.key, required this.walk});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('EEEE d MMMM yyyy, HH:mm', 'it');
    final currentUser = ref.watch(authServiceProvider).currentUser;
    final isParticipant = currentUser != null && walk.participants.contains(currentUser.uid);

    final isCreator = currentUser != null && walk.creatorId == currentUser.uid;
    print('DEBUG: Current User ID: ${currentUser?.uid}');
    print('DEBUG: Walk Creator ID: ${walk.creatorId}');
    final walkState = ref.watch(walkControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dettagli Passeggiata'),
        actions: [
          if (isCreator)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateWalkScreen(walkToEdit: walk),
                    ),
                  );
                } else if (value == 'delete') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Elimina Passeggiata'),
                      content: const Text('Sei sicuro di voler eliminare questa passeggiata?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Annulla'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(foregroundColor: AppColors.error),
                          child: const Text('Elimina'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await ref.read(walkControllerProvider.notifier).deleteWalk(walk.id);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Passeggiata eliminata')),
                      );
                    }
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: AppColors.textPrimary),
                      SizedBox(width: 8),
                      Text('Modifica'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('Elimina', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              walk.title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    walk.status.displayName,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                if (isCreator)
                  const Chip(
                    label: Text('Organizzatore'),
                    backgroundColor: AppColors.secondary,
                    labelStyle: TextStyle(color: Colors.white),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Organized By
            FutureBuilder<UserModel?>(
              future: UserService().getUserById(walk.creatorId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final creator = snapshot.data!;
                return InkWell(
                  onTap: () => showUserProfileBottomSheet(context, creator),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: creator.photoUrl != null
                            ? NetworkImage(creator.photoUrl!)
                            : null,
                        child: creator.photoUrl == null
                            ? Text(creator.firstName[0].toUpperCase())
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Organizzato da ${creator.fullName}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Info Grid
            _InfoRow(
              icon: Icons.calendar_today,
              label: 'Quando',
              value: dateFormat.format(walk.date),
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.timer,
              label: 'Durata',
              value: '${walk.duration} minuti',
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.location_on,
              label: 'Dove',
              value: walk.meetingPoint.address,
            ),
            const SizedBox(height: 24),

            // Description
            Text(
              'Descrizione',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              walk.description,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),

            // Participants
            Text(
              'Partecipanti (${walk.participants.length})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            // TODO: List participants with avatars
            // For now just a placeholder list
            SizedBox(
              height: 70,
              child: walk.participants.isEmpty
                  ? const Center(child: Text('Nessun partecipante ancora'))
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: walk.participants.length,
                      itemBuilder: (context, index) {
                        final userId = walk.participants[index];
                        return FutureBuilder<UserModel?>(
                          future: UserService().getUserById(userId),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Padding(
                                padding: EdgeInsets.only(right: 8.0),
                                child: CircleAvatar(
                                  radius: 24,
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final participant = snapshot.data!;
                            return Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: InkWell(
                                onTap: () => showUserProfileBottomSheet(context, participant),
                                borderRadius: BorderRadius.circular(24),
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundImage: participant.photoUrl != null
                                          ? NetworkImage(participant.photoUrl!)
                                          : null,
                                      child: participant.photoUrl == null
                                          ? Text(participant.firstName[0].toUpperCase())
                                          : null,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      participant.firstName,
                                      style: Theme.of(context).textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 32),

            // Action Button
            if (!isCreator && walk.isUpcoming)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: walkState.isLoading
                      ? null
                      : () {
                          if (isParticipant) {
                            ref
                                .read(walkControllerProvider.notifier)
                                .leaveWalk(walk.id);
                          } else {
                            ref
                                .read(walkControllerProvider.notifier)
                                .joinWalk(walk.id);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isParticipant ? Colors.red : AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: walkState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isParticipant ? 'Abbandona' : 'Partecipa'),
                ),
              )
            else if (isCreator)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: null, // Disabled
                  icon: const Icon(Icons.star, color: Colors.orange),
                  label: const Text('Sei l\'organizzatore', style: TextStyle(color: Colors.black54)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
