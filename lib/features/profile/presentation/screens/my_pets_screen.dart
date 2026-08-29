import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/dog_model.dart';
import '../../../../shared/models/announcement_model.dart';
import '../providers/dog_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'create_dog_profile_screen.dart'; // Same directory
import '../../../health_record/presentation/screens/health_record_list_screen.dart'; // Correct relative path
import '../../../../core/services/location_service.dart';
import '../../../../features/map/presentation/providers/map_provider.dart'; 
import '../../../../core/services/sos_service.dart';
import '../../../nextdoor/presentation/providers/nextdoor_provider.dart';

class MyPetsScreen extends ConsumerWidget {
  const MyPetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dogService = ref.watch(dogServiceProvider);
    final currentUser = ref.watch(authServiceProvider).currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Effettua l\'accesso per vedere i tuoi pet')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('I Miei Pet'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CreateDogProfileScreen()),
          );
        },
        label: const Text('Aggiungi Pet', style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // SOS Button Section
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red,
                  elevation: 0,
                  side: BorderSide(color: Colors.red.shade200),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => _showSOSDialog(context, ref, currentUser.uid),
                icon: const Icon(Icons.pets, size: 32),
                label: const Column(
                  children: [
                    Text('PET SMARRITO', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Segnala smarrimento alla community', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),

            // Pets List
            StreamBuilder<List<DogModel>>(
              stream: dogService.getDogsStreamByOwnerId(currentUser.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Errore: ${snapshot.error}'));
                }

                final dogs = snapshot.data ?? [];

                if (dogs.isEmpty) {
                  return Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        Icon(Icons.pets, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Non hai ancora aggiunto nessun pet',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: dogs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final dog = dogs[index];
                    return _PetCard(dog: dog);
                  },
                );
              },
            ),
             // Extra space for FAB
             const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  void _showSOSDialog(BuildContext context, WidgetRef ref, String userId) async {
    final dogs = await ref.read(dogServiceProvider).getDogsByOwnerId(userId);
    
    if (dogs.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aggiungi prima un cane al tuo profilo!')),
        );
      }
      return;
    }

    String? selectedPetId = dogs.first.id;
    final phoneController = TextEditingController();
    final messageController = TextEditingController();
    File? pickedImageFile;
    // Pre-load pet profile photo
    String? petPhotoUrl = dogs.first.photoUrl;
    bool useProfilePhoto = petPhotoUrl != null;

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            // Get currently selected dog
            final selectedDog = dogs.firstWhere(
              (d) => d.id == selectedPetId,
              orElse: () => dogs.first,
            );

            return AlertDialog(
              title: const Text('Lancia SOS Smarrimento 🚨', style: TextStyle(color: Colors.red)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Invia una notifica di emergenza a tutti gli utenti nelle vicinanze.'),
                    const SizedBox(height: 16),
                    
                    // Pet Selector
                    DropdownButtonFormField<String>(
                      value: selectedPetId,
                      decoration: const InputDecoration(labelText: 'Quale pet hai smarrito?'),
                      items: dogs.map((dog) => DropdownMenuItem(
                        value: dog.id,
                        child: Text(dog.name),
                      )).toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedPetId = val;
                          final dog = dogs.firstWhere((d) => d.id == val);
                          petPhotoUrl = dog.photoUrl;
                          useProfilePhoto = petPhotoUrl != null;
                          pickedImageFile = null; // Reset picked photo
                        });
                      },
                    ),
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
                          // Photo preview
                          if (pickedImageFile != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                pickedImageFile!,
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            )
                          else if (useProfilePhoto && petPhotoUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                petPhotoUrl!,
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 120,
                                  color: Colors.grey.shade200,
                                  child: const Center(child: Icon(Icons.broken_image, size: 40)),
                                ),
                              ),
                            )
                          else
                            Container(
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Text('Nessuna foto', style: TextStyle(color: Colors.grey)),
                              ),
                            ),
                          const SizedBox(height: 8),
                          // Photo source buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              if (petPhotoUrl != null)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        pickedImageFile = null;
                                        useProfilePhoto = true;
                                      });
                                    },
                                    icon: Icon(
                                      Icons.pets,
                                      size: 16,
                                      color: useProfilePhoto && pickedImageFile == null
                                          ? AppColors.primary
                                          : Colors.grey,
                                    ),
                                    label: Text(
                                      'Profilo',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: useProfilePhoto && pickedImageFile == null
                                            ? AppColors.primary
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: useProfilePhoto && pickedImageFile == null
                                            ? AppColors.primary
                                            : Colors.grey.shade300,
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    ),
                                  ),
                                ),
                              if (petPhotoUrl != null) const SizedBox(width: 6),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final picked = await ImagePicker().pickImage(
                                      source: ImageSource.camera,
                                      maxWidth: 800,
                                      imageQuality: 80,
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        pickedImageFile = File(picked.path);
                                        useProfilePhoto = false;
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.camera_alt, size: 16),
                                  label: const Text('Scatta', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final picked = await ImagePicker().pickImage(
                                      source: ImageSource.gallery,
                                      maxWidth: 800,
                                      imageQuality: 80,
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        pickedImageFile = File(picked.path);
                                        useProfilePhoto = false;
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.photo_library, size: 16),
                                  label: const Text('Galleria', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Phone
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
                    
                    // Message
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

                    // Get current location
                    try {
                      final position = await ref.read(locationServiceProvider).getCurrentPosition();
                      if (selectedPetId != null) {
                        // 1. Send SOS alert (map + push notification)
                        final alertId = await ref.read(sosServiceProvider).triggerSOS(
                          ownerId: userId,
                          petId: selectedPetId!,
                          latitude: position.latitude,
                          longitude: position.longitude,
                          contactPhone: phoneController.text,
                          message: messageController.text,
                        );

                        // 2. Auto-create bacheca announcement with 'lost' category + photo
                        final petName = selectedDog.name;
                        final phone = phoneController.text;
                        final userMessage = messageController.text;
                        
                        final announcementMessage = '🆘 PET SMARRITO: $petName\n'
                            '${userMessage.isNotEmpty ? '$userMessage\n' : ''}'
                            '📞 Contatto: $phone\n'
                            'Se lo avvisti, contattami subito!';

                        try {
                          final announcementId = await ref.read(nextdoorControllerProvider.notifier).createAnnouncement(
                            message: announcementMessage,
                            zone: 'Nelle vicinanze',
                            durationInHours: 72, // 3 days for lost pet
                            category: AnnouncementCategory.lost,
                            latitude: position.latitude,
                            longitude: position.longitude,
                            // Pass pet photo: new file takes priority, otherwise use profile URL
                            imageFile: pickedImageFile,
                            imageUrl: pickedImageFile == null ? petPhotoUrl : null,
                          );

                          // 3. Link SOS alert to announcement for comment support
                          await ref.read(sosServiceProvider).linkAnnouncement(alertId, announcementId);
                        } catch (e) {
                          // Non-critical: SOS was sent, announcement is a bonus
                          debugPrint('Failed to create bacheca announcement: $e');
                        }
                        
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('SOS Inviato! Tutti gli utenti sono stati avvisati.')),
                          );
                        }
                      } else {
                         throw Exception("Posizione non trovata");
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
          }
        ),
      );
    }
  }
}

class _PetCard extends StatelessWidget {
  final DogModel dog;
  const _PetCard({required this.dog});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header Image with Name Integration
          Stack(
            children: [
              Container(
                height: 140,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  image: dog.photoUrl != null
                      ? DecorationImage(image: NetworkImage(dog.photoUrl!), fit: BoxFit.cover)
                      : null,
                ),
                child: dog.photoUrl == null
                    ? const Center(child: Icon(Icons.pets, size: 48, color: Colors.white))
                    : null,
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          dog.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.5)),
                        ),
                        child: Text(
                          '${dog.age} anni',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
          
          // Details & Actions
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                     Icon(dog.gender == DogGender.male ? Icons.male : Icons.female, 
                          color: dog.gender == DogGender.male ? Colors.blue : Colors.pink),
                     const SizedBox(width: 8),
                     Text(
                       '${dog.breed} • ${dog.size.displayName}',
                       style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
                     ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                           Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreateDogProfileScreen(dogToEdit: dog),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Modifica'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade50,
                          foregroundColor: Colors.blue.shade700,
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HealthRecordListScreen(
                                dog: dog,
                                isOwner: true,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.medical_services, size: 18),
                        label: const Text('Libretto'),
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
}
