import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/sos_service.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../features/nextdoor/presentation/providers/nextdoor_provider.dart';
import '../../models/dog_model.dart';
import '../../models/announcement_model.dart';
import '../../../features/map/presentation/providers/map_provider.dart';

void showSOSDialog(BuildContext context, WidgetRef ref, DogModel dog) async {
  final currentUser = ref.read(authServiceProvider).currentUser;
  if (currentUser == null) return;

  final phoneController = TextEditingController();
  final messageController = TextEditingController();
  File? pickedImageFile;
  String? petPhotoUrl = dog.photoUrl;
  bool useProfilePhoto = petPhotoUrl != null;

  if (context.mounted) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Lancia SOS Smarrimento 🚨', style: TextStyle(color: Colors.red)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Stai segnalando lo smarrimento di ${dog.name}.\nInvieremo una notifica di emergenza a tutti gli utenti nelle vicinanze.'),
                  const SizedBox(height: 16),

                  // Photo Section
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        const Text(
                          '📸 Foto del pet (molto importante!)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        if (pickedImageFile != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(pickedImageFile!, height: 120, width: double.infinity, fit: BoxFit.cover),
                          )
                        else if (useProfilePhoto && petPhotoUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(petPhotoUrl, height: 120, width: double.infinity, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                height: 120, color: Colors.grey.shade200,
                                child: const Center(child: Icon(Icons.broken_image, size: 40)),
                              ),
                            ),
                          )
                        else
                          Container(
                            height: 80,
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                            child: const Center(child: Text('Nessuna foto', style: TextStyle(color: Colors.grey))),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if (petPhotoUrl != null)
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => setState(() { pickedImageFile = null; useProfilePhoto = true; }),
                                  icon: Icon(Icons.pets, size: 16, color: useProfilePhoto && pickedImageFile == null ? AppColors.primary : Colors.grey),
                                  label: Text('Profilo', style: TextStyle(fontSize: 12, color: useProfilePhoto && pickedImageFile == null ? AppColors.primary : Colors.grey.shade700)),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: useProfilePhoto && pickedImageFile == null ? AppColors.primary : Colors.grey.shade300),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  ),
                                ),
                              ),
                            if (petPhotoUrl != null) const SizedBox(width: 6),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 800, imageQuality: 80);
                                  if (picked != null) setState(() { pickedImageFile = File(picked.path); useProfilePhoto = false; });
                                },
                                icon: const Icon(Icons.camera_alt, size: 16),
                                label: const Text('Scatta', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 80);
                                  if (picked != null) setState(() { pickedImageFile = File(picked.path); useProfilePhoto = false; });
                                },
                                icon: const Icon(Icons.photo_library, size: 16),
                                label: const Text('Galleria', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Numero di contatto (Obbligatorio)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: messageController,
                    decoration: const InputDecoration(
                      labelText: 'Messaggio / Dove è stato visto?',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annulla'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () async {
                  if (phoneController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Inserisci un numero di telefono!')),
                    );
                    return;
                  }
                  try {
                    final position = await ref.read(locationServiceProvider).getCurrentPosition();
                    final alertId = await ref.read(sosServiceProvider).triggerSOS(
                      ownerId: currentUser.uid,
                      petId: dog.id,
                      latitude: position.latitude,
                      longitude: position.longitude,
                      contactPhone: phoneController.text,
                      message: messageController.text,
                    );

                    // Auto-create bacheca announcement
                    final announcementMessage = '🆘 PET SMARRITO: ${dog.name}\n'
                        '${messageController.text.isNotEmpty ? '${messageController.text}\n' : ''}'
                        '📞 Contatto: ${phoneController.text}\n'
                        'Se lo avvisti, contattami subito!';

                    try {
                      final announcementId = await ref.read(nextdoorControllerProvider.notifier).createAnnouncement(
                        message: announcementMessage,
                        zone: 'Nelle vicinanze',
                        durationInHours: 72,
                        category: AnnouncementCategory.lost,
                        latitude: position.latitude,
                        longitude: position.longitude,
                        imageFile: pickedImageFile,
                        imageUrl: pickedImageFile == null ? petPhotoUrl : null,
                      );
                      await ref.read(sosServiceProvider).linkAnnouncement(alertId, announcementId);
                    } catch (e) {
                      debugPrint('Failed to create bacheca announcement: $e');
                    }

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('SOS Inviato! Tutti gli utenti sono stati avvisati.')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Errore invio SOS: $e')),
                      );
                    }
                  }
                },
                child: const Text('INVIA SOS'),
              ),
            ],
          );
        },
      ),
    );
  }
}
