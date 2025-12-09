import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_model.dart';
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
  final _picker = ImagePicker();
  
  Gender? _selectedGender;
  DateTime? _selectedBirthDate;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.userToEdit?.firstName);
    _lastNameController = TextEditingController(text: widget.userToEdit?.lastName);
    _bioController = TextEditingController(text: widget.userToEdit?.bio);
    _zoneController = TextEditingController(text: widget.userToEdit?.zone);
    _addressController = TextEditingController(text: widget.userToEdit?.address);
    
    _selectedGender = widget.userToEdit?.gender;
    _selectedBirthDate = widget.userToEdit?.birthDate;
    
    _birthDateController = TextEditingController(
      text: _selectedBirthDate != null 
          ? '${_selectedBirthDate!.day}/${_selectedBirthDate!.month}/${_selectedBirthDate!.year}' 
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
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
        _birthDateController.text = '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      if (_imageFile == null && widget.userToEdit == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Per favore aggiungi una foto profilo'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }

      if (widget.userToEdit != null) {
        // Update existing profile
        ref.read(profileControllerProvider.notifier).updateProfile(
              firstName: _firstNameController.text.trim(),
              lastName: _lastNameController.text.trim(),
              zone: _zoneController.text.trim(),
              bio: _bioController.text.trim(),
              imageFile: _imageFile,
              gender: _selectedGender,
              birthDate: _selectedBirthDate,
              address: _addressController.text.trim(),
            );
      } else {
        // Create new profile
        ref.read(profileControllerProvider.notifier).createProfile(
              firstName: _firstNameController.text.trim(),
              lastName: _lastNameController.text.trim(),
              zone: _zoneController.text.trim(),
              bio: _bioController.text.trim(),
              imageFile: _imageFile,
              gender: _selectedGender,
              birthDate: _selectedBirthDate,
              address: _addressController.text.trim(),
            );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    final isEditing = widget.userToEdit != null;

    // Listen for errors and success
    ref.listen(profileControllerProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
          ),
        );
      } else if (!next.isLoading && previous?.isLoading == true && next.error == null) {
        // Success
        if (isEditing) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profilo aggiornato con successo')),
          );
          Navigator.pop(context);
        }
      }
    });

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
            children: [
              // Profile Image Picker
              GestureDetector(
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
                        : widget.userToEdit?.photoUrl != null
                            ? DecorationImage(
                                image: NetworkImage(widget.userToEdit!.photoUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                    border: Border.all(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  child: _imageFile == null && widget.userToEdit?.photoUrl == null
                      ? const Icon(
                          Icons.camera_alt,
                          size: 40,
                          color: AppColors.textTertiary,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Aggiungi foto',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 32),

              // First Name
              TextFormField(
                controller: _firstNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Inserisci il tuo nome';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Last Name
              TextFormField(
                controller: _lastNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Cognome',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Inserisci il tuo cognome';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Gender Dropdown
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
              ),
              const SizedBox(height: 16),

              // Birth Date Picker
              TextFormField(
                controller: _birthDateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Data di Nascita',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                onTap: () => _selectBirthDate(context),
              ),
              const SizedBox(height: 16),

              // Address
              TextFormField(
                controller: _addressController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Indirizzo',
                  prefixIcon: Icon(Icons.home_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Zone (Temporary text field)
              TextFormField(
                controller: _zoneController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Zona (es. Milano Centro)',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Inserisci la tua zona';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Bio
              TextFormField(
                controller: _bioController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Bio (opzionale)',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.edit_note),
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: profileState.isLoading ? null : _handleSubmit,
                  child: profileState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
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
