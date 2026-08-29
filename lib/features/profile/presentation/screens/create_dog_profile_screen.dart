import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/dog_model.dart';
import '../../../../shared/data/breeds_data.dart'; // Added
import '../../../../shared/utils/breed_validator.dart';
import '../providers/dog_provider.dart';
import '../widgets/pet_photo_picker.dart';
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
  
  late TextEditingController _weightController;
  late TextEditingController _microchipController;
  late TextEditingController _bloodTypeController;
  
  late DogSize _selectedSize;
  late DogGender _selectedGender;
  late PetSpecies _selectedSpecies; // Added
  late bool _isSterilized;
  late double _energyLevel;
  late List<String> _selectedCharacter;
  
  File? _imageFile;
  final _picker = ImagePicker();

  // Multi-photo state
  List<String> _selectedMediaUrls = [];
  List<File> _newMediaFiles = [];

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
    
    _weightController = TextEditingController(text: widget.dogToEdit?.weight?.toString() ?? '');
    _microchipController = TextEditingController(text: widget.dogToEdit?.microchipNumber ?? '');
    _bloodTypeController = TextEditingController(text: widget.dogToEdit?.bloodType ?? '');
    
    _selectedSize = widget.dogToEdit?.size ?? DogSize.medium;
    _selectedGender = widget.dogToEdit?.gender ?? DogGender.male;
    _selectedSpecies = widget.dogToEdit?.species ?? PetSpecies.dog; // Added
    _isSterilized = widget.dogToEdit?.isSterilized ?? false;
    _energyLevel = widget.dogToEdit?.energyLevel.toDouble() ?? 3.0;
    _selectedCharacter = List.from(widget.dogToEdit?.character ?? []);
    _selectedMediaUrls = List.from(widget.dogToEdit?.mediaUrls ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _notesController.dispose();
    _weightController.dispose();
    _microchipController.dispose();
    _bloodTypeController.dispose();
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

  Future<void> _openPhotoPicker() async {
    final result = await showModalBottomSheet<PetPhotoPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PetPhotoPicker(
        alreadySelected: _selectedMediaUrls,
        maxPhotos: 9,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedMediaUrls = result.selectedUrls;
        _newMediaFiles = result.newFiles;
      });
    }
  }

  void _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      // Dismiss keyboard
      FocusScope.of(context).unfocus();
      
      final controller = ref.read(dogControllerProvider.notifier);
      
      // Validate and auto-correct breed
      final rawBreed = _breedController.text.trim();
      final validatedBreed = BreedValidator.validate(rawBreed, _selectedSpecies);
      _breedController.text = validatedBreed;

      // Show a snackbar if breed was corrected
      if (rawBreed.isNotEmpty && rawBreed.toLowerCase() != validatedBreed.toLowerCase()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Razza corretta: "$rawBreed" → "$validatedBreed"'),
              backgroundColor: AppColors.info,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
      
      double? weight = double.tryParse(_weightController.text.trim().replaceAll(',', '.'));
      String? microchip = _microchipController.text.trim().isEmpty ? null : _microchipController.text.trim();
      String? bloodType = _bloodTypeController.text.trim().isEmpty ? null : _bloodTypeController.text.trim();

      if (widget.dogToEdit != null) {
        await controller.updateDog(
          id: widget.dogToEdit!.id,
          name: _nameController.text.trim(),
          breed: validatedBreed,
          age: int.parse(_ageController.text.trim()),
          size: _selectedSize,
          energyLevel: _energyLevel.round(),
          character: _selectedCharacter,
          notes: _notesController.text.trim(),
          imageFile: _imageFile,
          currentPhotoUrl: widget.dogToEdit!.photoUrl,
          gender: _selectedGender,
          species: _selectedSpecies,
          weight: weight,
          microchipNumber: microchip,
          bloodType: bloodType,
          existingMediaUrls: _selectedMediaUrls,
          newMediaFiles: _newMediaFiles,
          isSterilized: _isSterilized,
        );
      } else {
        await controller.createDog(
          name: _nameController.text.trim(),
          breed: validatedBreed,
          age: int.parse(_ageController.text.trim()),
          size: _selectedSize,
          energyLevel: _energyLevel.round(),
          character: _selectedCharacter,
          notes: _notesController.text.trim(),
          imageFile: _imageFile,
          gender: _selectedGender,
          species: _selectedSpecies,
          weight: weight,
          microchipNumber: microchip,
          bloodType: bloodType,
          existingMediaUrls: _selectedMediaUrls,
          newMediaFiles: _newMediaFiles,
          isSterilized: _isSterilized,
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

              // === PHOTO GRID ===
              const Text('Foto del Pet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _buildMediaGrid(),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _openPhotoPicker,
                  icon: const Icon(Icons.add_photo_alternate, size: 20),
                  label: Text(
                    _totalMediaCount == 0 ? 'Aggiungi foto' : 'Gestisci foto ($_totalMediaCount/9)',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              
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
                            dog: widget.dogToEdit!,
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
                    decoration: InputDecoration(
                      labelText: 'Razza',
                      prefixIcon: const Icon(Icons.category),
                      helperText: 'Seleziona dalla lista o scrivi — correggiamo noi',
                      helperMaxLines: 2,
                      suffixIcon: _breedController.text.isNotEmpty &&
                              !BreedValidator.isValid(_breedController.text, _selectedSpecies)
                          ? Tooltip(
                              message: 'Razza non riconosciuta — verrà corretta automaticamente',
                              child: Icon(Icons.auto_fix_high, color: Colors.orange.shade600, size: 20),
                            )
                          : null,
                    ),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Inserisci la razza' : null,
                    onChanged: (val) {
                      _breedController.text = val;
                      setState(() {}); // Refresh suffix icon
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
              
              // Weight
              TextFormField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Peso (kg)',
                  prefixIcon: Icon(Icons.monitor_weight),
                ),
              ),
              const SizedBox(height: 16),

              // Microchip
              TextFormField(
                controller: _microchipController,
                decoration: const InputDecoration(
                  labelText: 'Numero Microchip',
                  prefixIcon: Icon(Icons.qr_code),
                ),
              ),
              const SizedBox(height: 16),

              // Blood Type
              TextFormField(
                controller: _bloodTypeController,
                decoration: const InputDecoration(
                  labelText: 'Gruppo Sanguigno',
                  prefixIcon: Icon(Icons.bloodtype),
                ),
              ),
              const SizedBox(height: 16),

              // Gender Dropdown
              DropdownButtonFormField<DogGender>(
                initialValue: _selectedGender,
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

              // Sterilized/Castrated switch
              SwitchListTile(
                title: Text(
                  _selectedGender == DogGender.male ? 'Castrato' : 'Sterilizzata',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  _selectedGender == DogGender.male
                      ? 'Il pet è stato castrato'
                      : 'La pet è stata sterilizzata',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                value: _isSterilized,
                activeColor: AppColors.primary,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                onChanged: (val) => setState(() => _isSterilized = val),
              ),
              const SizedBox(height: 16),

              // Size Dropdown
              DropdownButtonFormField<DogSize>(
                initialValue: _selectedSize,
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
                    backgroundColor: Colors.grey.shade100,
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    checkmarkColor: AppColors.primary,
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
  int get _totalMediaCount => _selectedMediaUrls.length + _newMediaFiles.length;

  Widget _buildMediaGrid() {
    final totalItems = _selectedMediaUrls.length + _newMediaFiles.length;
    if (totalItems == 0) {
      return GestureDetector(
        onTap: _openPhotoPicker,
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2, style: BorderStyle.solid),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo, size: 40, color: AppColors.primary),
                SizedBox(height: 8),
                Text('Aggiungi fino a 9 foto', style: TextStyle(color: AppColors.primary, fontSize: 13)),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 90,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Existing URL photos
          ..._selectedMediaUrls.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(entry.value, width: 86, height: 86, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(width: 86, height: 86, color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, color: Colors.grey))),
                  ),
                  if (entry.key == 0)
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        width: 86,
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.8),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                        ),
                        child: const Text('Principale', textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
            );
          }),
          // New file photos
          ..._newMediaFiles.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(entry.value, width: 86, height: 86, fit: BoxFit.cover),
              ),
            );
          }),
          // Add more button
          if (totalItems < 9)
            GestureDetector(
              onTap: _openPhotoPicker,
              child: Container(
                width: 86, height: 86,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Center(child: Icon(Icons.add, color: Colors.grey, size: 30)),
              ),
            ),
        ],
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
