import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/dog_model.dart';
import '../providers/dog_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'create_dog_profile_screen.dart'; // Same directory
import '../../../health_record/presentation/screens/health_record_list_screen.dart'; // Correct relative path
import '../../../../core/services/location_service.dart';
import '../../../../features/map/presentation/providers/map_provider.dart'; 
import '../../../../core/services/sos_service.dart';

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
                      onChanged: (val) => setState(() => selectedPetId = val),
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
                      if (position != null && selectedPetId != null) {
                        await ref.read(sosServiceProvider).triggerSOS(
                          ownerId: userId,
                          petId: selectedPetId!,
                          latitude: position.latitude,
                          longitude: position.longitude,
                          contactPhone: phoneController.text,
                          message: messageController.text,
                        );
                        
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
                                petId: dog.id, 
                                petName: dog.name,
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
