import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/dog_model.dart';
import '../../../../shared/data/breeds_data.dart'; // Added
import '../providers/dog_provider.dart';
import '../../../../features/health_record/presentation/screens/health_record_list_screen.dart';

class CreateDogProfileScreen extends ConsumerStatefulWidget {
  final DogModel? dogToEdit;

  const CreateDogProfileScreen({super.key, this.dogToEdit});

  @override
  ConsumerState<CreateDogProfileScreen> createState() => _CreateDogProfileScreenState();
}

class _CreateDogProfileScreenState extends ConsumerState<CreateDogProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  final TextEditingController _breedController = TextEditingController(); // Managed differently for autocomplete
  late TextEditingController _ageController;
  late TextEditingController _notesController;
  
  late DogSize _selectedSize;
  late DogGender _selectedGender;
  late PetSpecies _selectedSpecies; // Added
  late double _energyLevel;
  late List<String> _selectedCharacter;
  
  File? _imageFile;
  final _picker = ImagePicker();

  final List<String> _characterTraits = [
    'Amichevole', 'Timido', 'Giocherellone', 'Calmo', 
    'Protettivo', 'Curioso', 'Indipendente', 'Affettuoso'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.dogToEdit?.name ?? '');
    // Breed controller is now handled via Autocomplete initialValue logic, 
    // but we keep a reference to read it or set initial text if using custom fieldViewBuilder
    _breedController.text = widget.dogToEdit?.breed ?? ''; 
    
    _ageController = TextEditingController(text: widget.dogToEdit?.age.toString() ?? '');
    _notesController = TextEditingController(text: widget.dogToEdit?.notes ?? '');
    
    _selectedSize = widget.dogToEdit?.size ?? DogSize.medium;
    _selectedGender = widget.dogToEdit?.gender ?? DogGender.male;
    _selectedSpecies = widget.dogToEdit?.species ?? PetSpecies.dog; // Added
    _energyLevel = widget.dogToEdit?.energyLevel.toDouble() ?? 3.0;
    _selectedCharacter = List.from(widget.dogToEdit?.character ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  void _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      // Dismiss keyboard
      FocusScope.of(context).unfocus();
      
      final controller = ref.read(dogControllerProvider.notifier);
      
      if (widget.dogToEdit != null) {
        await controller.updateDog(
          id: widget.dogToEdit!.id,
          name: _nameController.text.trim(),
          breed: _breedController.text.trim(),
          age: int.parse(_ageController.text.trim()),
          size: _selectedSize,
          energyLevel: _energyLevel.round(),
          character: _selectedCharacter,
          notes: _notesController.text.trim(),
          imageFile: _imageFile,
          currentPhotoUrl: widget.dogToEdit!.photoUrl,
          gender: _selectedGender,
          species: _selectedSpecies, // Added
        );
      } else {
        await controller.createDog(
          name: _nameController.text.trim(),
          breed: _breedController.text.trim(),
          age: int.parse(_ageController.text.trim()),
          size: _selectedSize,
          energyLevel: _energyLevel.round(),
          character: _selectedCharacter,
          notes: _notesController.text.trim(),
          imageFile: _imageFile,
          gender: _selectedGender,
          species: _selectedSpecies, // Added
        );
      }
          
      // Check for error in state
      if (mounted) {
        final state = ref.read(dogControllerProvider);
        if (state.error == null) {
          Navigator.pop(context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dogState = ref.watch(dogControllerProvider);
    final isEditing = widget.dogToEdit != null;

    ref.listen<DogState>(dogControllerProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Modifica Pet' : 'Aggiungi Pet'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Species Selection (Big Cards)
              Row(
                children: [
                  Expanded(
                    child: _buildSpeciesCard(
                      PetSpecies.dog, 
                      Icons.pets, 
                      'Cane'
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSpeciesCard(
                      PetSpecies.cat, 
                      Icons.catching_pokemon, // Use a cat-like icon if available, or just generic
                      'Gatto'
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Image Picker
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      shape: BoxShape.circle,
                      image: _imageFile != null
                          ? DecorationImage(
                              image: FileImage(_imageFile!),
                              fit: BoxFit.cover,
                            )
                          : (widget.dogToEdit?.photoUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(widget.dogToEdit!.photoUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null),
                      border: Border.all(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    child: (_imageFile == null && widget.dogToEdit?.photoUrl == null)
                        ? const Icon(
                            Icons.add_a_photo,
                            size: 40,
                            color: AppColors.textTertiary,
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(child: Text('Foto del Pet')),
              
              if (isEditing && widget.dogToEdit != null) ...[
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.medical_services, color: Colors.green),
                    title: const Text(
                      'Libretto Sanitario',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    subtitle: const Text('Vaccini, visite e scadenze'),
                    trailing: const Icon(Icons.chevron_right, color: Colors.green),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HealthRecordListScreen(
                            petId: widget.dogToEdit!.id,
                            petName: widget.dogToEdit!.name,
                            isOwner: true, 
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              
              const SizedBox(height: 32),

              // Name
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Inserisci il nome' : null,
              ),
              const SizedBox(height: 16),

              // Breed Autocomplete
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _breedController.text),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text == '') {
                    return const Iterable<String>.empty();
                  }
                  final query = textEditingValue.text.toLowerCase();
                  final breeds = _selectedSpecies == PetSpecies.dog 
                      ? BreedsData.dogBreeds 
                      : BreedsData.catBreeds;
                  
                  // Logic for synonyms
                  if (query.contains('bastard')) {
                     return ['Meticcio / Incrocio'];
                  }

                  return breeds.where((String option) {
                    return option.toLowerCase().contains(query);
                  });
                },
                onSelected: (String selection) {
                  _breedController.text = selection;
                },
                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                  // Sync the autocomplete controller with our manual _breedController
                  // actually we can just pass _breedController if we listen to changes, but easier to use theirs
                  // and sync back to ours on submit or change.
                  // BETTER: Use their controller for the UI, and in onChanged update ours.
                  
                  // Wait, we need to handle the initial value correctly.
                  if (_breedController.text.isNotEmpty && textEditingController.text.isEmpty) {
                    textEditingController.text = _breedController.text;
                  }

                  return TextFormField(
                    controller: textEditingController, // Use the Autocomplete's controller
                    focusNode: focusNode,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Razza',
                      prefixIcon: Icon(Icons.category),
                      helperText: 'Seleziona dalla lista',
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Inserisci la razza' : null,
                    onChanged: (val) {
                      _breedController.text = val;
                    },
                  );
                },
              ),
              const SizedBox(height: 16),

              // Age
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Età (anni)',
                  prefixIcon: Icon(Icons.cake),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Inserisci l\'età';
                  if (int.tryParse(value) == null) return 'Inserisci un numero valido';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Gender Dropdown
              DropdownButtonFormField<DogGender>(
                value: _selectedGender,
                decoration: const InputDecoration(
                  labelText: 'Sesso',
                  prefixIcon: Icon(Icons.wc),
                ),
                items: DogGender.values.map((gender) {
                  return DropdownMenuItem(
                    value: gender,
                    child: Text(gender.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedGender = value);
                  }
                },
              ),
              const SizedBox(height: 24),

              // Size Dropdown
              DropdownButtonFormField<DogSize>(
                value: _selectedSize,
                decoration: const InputDecoration(
                  labelText: 'Taglia',
                  prefixIcon: Icon(Icons.straighten),
                ),
                items: DogSize.values.map((size) {
                  return DropdownMenuItem(
                    value: size,
                    child: Text(size.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedSize = value);
                  }
                },
              ),
              const SizedBox(height: 24),

              // Energy Level Slider
              Text('Livello di energia: ${_energyLevel.round()}/5'),
              Slider(
                value: _energyLevel,
                min: 1,
                max: 5,
                divisions: 4,
                label: _energyLevel.round().toString(),
                onChanged: (value) {
                  setState(() => _energyLevel = value);
                },
              ),
              const SizedBox(height: 16),

              // Character Traits (Chips)
              Text('Carattere', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _characterTraits.map((trait) {
                  final isSelected = _selectedCharacter.contains(trait);
                  return FilterChip(
                    label: Text(trait),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedCharacter.add(trait);
                        } else {
                          _selectedCharacter.remove(trait);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Note utili (es. allergie, paure)',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.note),
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: dogState.isLoading ? null : _handleSubmit,
                  child: dogState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isEditing ? 'Salva Modifiche' : 'Salva Pet'),
                ),
              ),
              if (isEditing) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: dogState.isLoading
                        ? null
                        : () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Elimina Pet'),
                                content: const Text(
                                    'Sei sicuro di voler eliminare questo profilo?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Annulla'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: TextButton.styleFrom(
                                        foregroundColor: AppColors.error),
                                    child: const Text('Elimina'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await ref
                                  .read(dogControllerProvider.notifier)
                                  .deleteDog(widget.dogToEdit!.id);
                              
                              if (mounted) {
                                final state = ref.read(dogControllerProvider);
                                if (state.error == null) {
                                  Navigator.pop(context); // Close screen
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Pet eliminato')),
                                  );
                                }
                              }
                            }
                          },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    child: const Text('Elimina Pet'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeciesCard(PetSpecies species, IconData icon, String label) {
    final isSelected = _selectedSpecies == species;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSpecies = species;
          // Clear breed when switching species to avoid "Golden Retriever" for a Cat
          _breedController.clear(); 
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: isSelected 
              ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon, 
              size: 40, 
              color: isSelected ? Colors.white : AppColors.textSecondary
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
