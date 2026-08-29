import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/constants/map_markers.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/widgets/address_autocomplete_field.dart';
import '../providers/profile_provider.dart';

class CreateProfileScreen extends ConsumerStatefulWidget {
  final UserModel? userToEdit;

  const CreateProfileScreen({super.key, this.userToEdit});

  @override
  ConsumerState<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends ConsumerState<CreateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _bioController;
  late TextEditingController _zoneController;
  late TextEditingController _addressController;
  late TextEditingController _birthDateController;

  File? _imageFile;
  Gender? _selectedGender;
  DateTime? _selectedBirthDate;
  String _selectedMapMarkerId = MapMarkers.defaultSmile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = widget.userToEdit;
    
    _firstNameController = TextEditingController(text: user?.firstName);
    _lastNameController = TextEditingController(text: user?.lastName);
    _bioController = TextEditingController(text: user?.bio);
    _zoneController = TextEditingController(text: user?.zone);
    _addressController = TextEditingController(text: user?.address);
    
    _selectedGender = user?.gender;
    _selectedBirthDate = user?.birthDate;
    
    if (user != null) {
       _selectedMapMarkerId = user.mapMarkerId;
    } else {
       // Check for Firebase Auth displayName from Apple Sign In
       final firebaseUser = FirebaseAuth.instance.currentUser;
       if (firebaseUser?.displayName != null && firebaseUser!.displayName!.isNotEmpty) {
          final parts = firebaseUser.displayName!.split(' ');
          if (parts.isNotEmpty) {
             _firstNameController.text = parts.first;
             if (parts.length > 1) {
                _lastNameController.text = parts.sublist(1).join(' ');
             }
          }
       }
    }

    _birthDateController = TextEditingController(
      text: _selectedBirthDate != null 
          ? DateFormat('dd/MM/yyyy').format(_selectedBirthDate!)
          : ''
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _bioController.dispose();
    _zoneController.dispose();
    _addressController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('it', 'IT'),
    );
    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
        _birthDateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_imageFile == null && widget.userToEdit == null && (widget.userToEdit?.photoUrl == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Per favore aggiungi una foto profilo'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.userToEdit != null) {
        // Update existing profile
        await ref.read(profileControllerProvider.notifier).updateProfile(
              firstName: _firstNameController.text.trim(),
              lastName: _lastNameController.text.trim(),
              zone: _zoneController.text.trim(),
              bio: _bioController.text.trim(),
              imageFile: _imageFile,
              gender: _selectedGender,
              birthDate: _selectedBirthDate,
              address: _addressController.text.trim(),
              mapMarkerId: _selectedMapMarkerId,
            );
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Profilo aggiornato con successo!')),
           );
           Navigator.pop(context);
         }
      } else {
        // Create new profile
        await ref.read(profileControllerProvider.notifier).createProfile(
              firstName: _firstNameController.text.trim(),
              lastName: _lastNameController.text.trim(),
              zone: _zoneController.text.trim(),
              bio: _bioController.text.trim(),
              imageFile: _imageFile,
              gender: _selectedGender,
              birthDate: _selectedBirthDate,
              address: _addressController.text.trim(),
              mapMarkerId: _selectedMapMarkerId,
            );
        // Assuming createProfile navigates or we handle it here
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.userToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Modifica Profilo' : 'Completa il Profilo'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Picker
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                          : (widget.userToEdit?.photoUrl != null
                              ? NetworkImage(widget.userToEdit!.photoUrl!) as ImageProvider
                              : null),
                      child: (_imageFile == null && widget.userToEdit?.photoUrl == null)
                          ? const Icon(Icons.person, size: 60, color: Colors.grey)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        backgroundColor: AppColors.primary,
                        radius: 20,
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          onPressed: _pickImage,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Names
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameController,
                      readOnly: _firstNameController.text.isNotEmpty && widget.userToEdit == null, // Read-only if pre-filled (Apple Sign In)
                      decoration: InputDecoration(
                        labelText: 'Nome',
                        prefixIcon: const Icon(Icons.person_outline),
                        helperText: (_firstNameController.text.isNotEmpty && widget.userToEdit == null) 
                            ? 'Verificato da Apple' 
                            : null,
                      ),
                      validator: (value) => 
                          value?.isEmpty ?? true ? 'Campo obbligatorio' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameController,
                      readOnly: _lastNameController.text.isNotEmpty && widget.userToEdit == null, // Read-only if pre-filled (Apple Sign In)
                      decoration: InputDecoration(
                        labelText: 'Cognome',
                        prefixIcon: const Icon(Icons.person_outline),
                         helperText: (_lastNameController.text.isNotEmpty && widget.userToEdit == null) 
                            ? 'Verificato da Apple' 
                            : null,
                      ),
                      validator: (value) => 
                          value?.isEmpty ?? true ? 'Campo obbligatorio' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Gender
              DropdownButtonFormField<Gender>(
                value: _selectedGender,
                decoration: const InputDecoration(
                  labelText: 'Genere',
                  prefixIcon: Icon(Icons.wc),
                ),
                items: Gender.values.map((gender) {
                  return DropdownMenuItem(
                    value: gender,
                    child: Text(gender.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value;
                  });
                },
                validator: (value) => value == null ? 'Seleziona un genere' : null,
              ),
              const SizedBox(height: 16),

              // Birth Date
              InkWell(
                onTap: () => _selectBirthDate(context),
                child: IgnorePointer(
                  child: TextFormField(
                    controller: _birthDateController,
                    decoration: const InputDecoration(
                      labelText: 'Data di Nascita',
                      helperText: 'Richiesto: Devi avere almeno 16 anni.',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    validator: (value) => 
                        value?.isEmpty ?? true ? 'Campo obbligatorio' : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              const Divider(),
              const SizedBox(height: 16),

              // Marker Selector Section
               Text(
                 'Avatar Mappa',
                 style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textSecondary),
               ),
               const SizedBox(height: 12),
               SizedBox(
                 height: 80,
                 child: ListView.separated(
                   scrollDirection: Axis.horizontal,
                   itemCount: MapMarkers.availableMarkers.length,
                   separatorBuilder: (context, index) => const SizedBox(width: 16),
                   itemBuilder: (context, index) {
                     final marker = MapMarkers.availableMarkers[index];
                     final id = marker['id'] as String;
                     final name = marker['name'] as String;
                     final isSelected = _selectedMapMarkerId == id;
                     final iconData = MapMarkers.getIcon(id);

                     return GestureDetector(
                       onTap: () {
                         setState(() {
                           _selectedMapMarkerId = id;
                         });
                       },
                       child: Column(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           Container(
                             width: 50,
                             height: 50,
                             decoration: BoxDecoration(
                               color: isSelected ? AppColors.primary : Colors.grey.shade100,
                               shape: BoxShape.circle,
                               border: Border.all(
                                 color: isSelected ? AppColors.primary : Colors.grey.shade300,
                                 width: 2,
                               ),
                               boxShadow: isSelected ? [
                                  BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
                               ] : null,
                             ),
                             child: Icon(
                               iconData,
                               color: isSelected ? Colors.white : Colors.grey.shade600,
                               size: 28,
                             ),
                           ),
                           const SizedBox(height: 4),
                           Text(
                             name,
                             style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? AppColors.primary : Colors.grey.shade600,
                             ),
                           ),
                         ],
                       ),
                     );
                   },
                 ),
               ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Address Integration
              Text(
                'Indirizzo',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              AddressAutocompleteField(
                controller: _addressController,
                label: 'Indirizzo (Opzionale)',
                onSelected: (prediction) async {
                   // Optional: If we want to get lat/long here we can, 
                   // but usually the controller text is enough for display
                   // and we trust the user to pick a valid one.
                   // The validation happens on save usually.
                   _addressController.text = prediction.displayName;
                   
                   // Auto-fill zone if possible?
                   // Simple heuristic: last part of address usually contains city/zone
                   final parts = prediction.displayName.split(',');
                   if (parts.length >= 2) {
                      // e.g. "Via Roma, Milano, MI, Italia" -> Pick "Milano"
                      // This is a rough guess, let user edit it.
                      if (_zoneController.text.isEmpty) {
                         _zoneController.text = parts[1].trim();
                      }
                   }
                }, 
                // validator: (value) => value?.isEmpty ?? true ? 'Campo obbligatorio' : null, // REMOVED for Privacy 5.1.1
              ),

              const SizedBox(height: 16),

              // Zone (Manual override)
              TextFormField(
                controller: _zoneController,
                decoration: const InputDecoration(
                  labelText: 'Zona / Quartiere',
                  prefixIcon: Icon(Icons.map),
                  hintText: 'Es. Centro Storico',
                ),
                validator: (value) => 
                    value?.isEmpty ?? true ? 'Campo obbligatorio' : null,
              ),

              const SizedBox(height: 16),

              // Bio
              TextFormField(
                controller: _bioController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 48),
                    child: Icon(Icons.edit_note),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  child: _isLoading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isEditing ? 'Salva Modifiche' : 'Crea Profilo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
