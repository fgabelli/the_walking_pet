import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/user_model.dart';
import '../providers/profile_provider.dart';

class BusinessProfileEditScreen extends ConsumerStatefulWidget {
  final UserModel user;

  const BusinessProfileEditScreen({super.key, required this.user});

  @override
  ConsumerState<BusinessProfileEditScreen> createState() => _BusinessProfileEditScreenState();
}

class _BusinessProfileEditScreenState extends ConsumerState<BusinessProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _bioController;
  late TextEditingController _addressController;
  late TextEditingController _websiteController;
  late TextEditingController _phoneController;
  late TextEditingController _instagramController;
  late TextEditingController _tiktokController;
  late TextEditingController _hoursController;
  String? _selectedCategory;
  bool _isLoading = false;

  File? _coverImageFile;
  final ImagePicker _picker = ImagePicker();

  final List<String> _categories = [
    'Veterinario',
    'Negozio per Animali',
    'Pet Sitter',
    'Addestratore',
    'Pensione',
    'Toelettatura',
    'Bar/Ristorante Pet Friendly',
    'Hotel/B&B Pet Friendly',
    'Spiaggia Pet Friendly',
    'Altro'
  ];

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(text: widget.user.bio);
    _addressController = TextEditingController(text: widget.user.address);
    _websiteController = TextEditingController(text: widget.user.website);
    _phoneController = TextEditingController(text: widget.user.phoneNumber);
    _instagramController = TextEditingController(text: widget.user.instagramHandle);
    _tiktokController = TextEditingController(text: widget.user.tiktokHandle);
    _hoursController = TextEditingController(text: widget.user.openingHours);
    _selectedCategory = widget.user.businessCategory;
    
    // Default cat if null and switching to business
    if (_selectedCategory == null && widget.user.accountType == AccountType.business) {
       // keep null let user choose
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    _addressController.dispose();
    _websiteController.dispose();
    _phoneController.dispose();
    _instagramController.dispose();
    _tiktokController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, maxHeight: 600);
    if (pickedFile != null) {
      setState(() {
        _coverImageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(profileControllerProvider.notifier).updateProfile(
        businessCategory: _selectedCategory,
        bio: _bioController.text.trim(),
        address: _addressController.text.trim(),
        website: _websiteController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        instagramHandle: _instagramController.text.trim(),
        tiktokHandle: _tiktokController.text.trim(),
        openingHours: _hoursController.text.trim(),
        coverImageFile: _coverImageFile,
        accountType: AccountType.business, // Force switch to business
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profilo Business aggiornato!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilo Business'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20, 
                height: 20, 
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Salva', style: TextStyle(fontWeight: FontWeight.bold)),
            )
        ],
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Image Area
              GestureDetector(
                onTap: _pickCoverImage,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    image: _coverImageFile != null
                        ? DecorationImage(image: FileImage(_coverImageFile!), fit: BoxFit.cover)
                        : (widget.user.coverImageUrl != null
                            ? DecorationImage(
                                image: NetworkImage(widget.user.coverImageUrl!),
                                fit: BoxFit.cover,
                              )
                            : null),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(color: Colors.black26),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.camera_alt, color: Colors.white, size: 40),
                          const SizedBox(height: 8),
                          Text(
                            _coverImageFile == null && widget.user.coverImageUrl == null
                                ? 'Aggiungi Copertina'
                                : 'Modifica Copertina',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoCard(context),
                    const SizedBox(height: 24),
                    
                    Text('Informazioni Principali', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    
                    // Bio
                    TextFormField(
                       controller: _bioController,
                       decoration: const InputDecoration(
                         labelText: 'Descrizione / Mission',
                         hintText: 'Racconta chi sei e cosa offri...',
                         alignLabelWithHint: true,
                         border: OutlineInputBorder(),
                       ),
                       maxLines: 4,
                       maxLength: 300,
                     ),
                     const SizedBox(height: 16),

                    // Categoria
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
                        prefixIcon: Icon(Icons.category),
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setState(() => _selectedCategory = val),
                    ),
                    const SizedBox(height: 16),
                    
                    // Address
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Indirizzo Completo',
                        prefixIcon: Icon(Icons.location_on),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text('Contatti', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),

                    // Website
                    TextFormField(
                      controller: _websiteController,
                      decoration: const InputDecoration(
                        labelText: 'Sito Web',
                        prefixIcon: Icon(Icons.language),
                        border: OutlineInputBorder(),
                        hintText: 'https://www.esempio.it'
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 16),
                    
                    // Phone
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Telefono',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 24),

                    Text('Social & Orari', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),

                    // Instagram
                    TextFormField(
                      controller: _instagramController,
                      decoration: const InputDecoration(
                        labelText: 'Instagram Handle',
                        prefixIcon: Icon(FontAwesomeIcons.instagram),
                        border: OutlineInputBorder(),
                        hintText: '@tuo.business'
                      ),
                    ),
                    const SizedBox(height: 16),

                    // TikTok
                    TextFormField(
                      controller: _tiktokController,
                      decoration: const InputDecoration(
                        labelText: 'TikTok Handle',
                        prefixIcon: Icon(FontAwesomeIcons.tiktok),
                        border: OutlineInputBorder(),
                        hintText: '@tuo.business'
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Opening Hours
                    TextFormField(
                      controller: _hoursController,
                      decoration: const InputDecoration(
                        labelText: 'Orari di Apertura',
                        prefixIcon: Icon(Icons.access_time),
                        border: OutlineInputBorder(),
                        hintText: 'Lun-Ven: 09:00 - 18:00'
                      ),
                      maxLines: 2,
                    ),
                    
                    const SizedBox(height: 32),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _save,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading 
                           ? const CircularProgressIndicator(color: Colors.white)
                           : Text(widget.user.accountType == AccountType.business ? 'Salva Modifiche' : 'Attiva Profilo Business'),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.store, color: AppColors.primary, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Profilo Business', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'Completa tutti i campi per rendere la tua vetrina accattivante per i clienti!',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
