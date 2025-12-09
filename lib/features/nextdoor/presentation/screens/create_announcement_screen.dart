import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/announcement_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import '../../../../shared/widgets/address_autocomplete_field.dart';
import '../providers/nextdoor_provider.dart';

class CreateAnnouncementScreen extends ConsumerStatefulWidget {
  final AnnouncementModel? announcementToEdit;

  const CreateAnnouncementScreen({super.key, this.announcementToEdit});

  @override
  ConsumerState<CreateAnnouncementScreen> createState() => _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends ConsumerState<CreateAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _zoneController = TextEditingController();
  int _durationInHours = 24;
  File? _imageFile;
  final _picker = ImagePicker();
  bool _isEditing = false;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    if (widget.announcementToEdit != null) {
      _isEditing = true;
      _messageController.text = widget.announcementToEdit!.message;
      _zoneController.text = widget.announcementToEdit!.zone;
      _latitude = widget.announcementToEdit!.location.latitude;
      _longitude = widget.announcementToEdit!.location.longitude;
      
      // Calculate remaining duration or just keep default/current?
      // Let's keep default for now or calculate from expiresAt
      final remaining = widget.announcementToEdit!.expiresAt.difference(DateTime.now()).inHours;
      _durationInHours = remaining > 0 ? remaining : 24;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _zoneController.dispose();
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
      FocusScope.of(context).unfocus();

      try {
        if (_isEditing) {
          final updatedAnnouncement = widget.announcementToEdit!.copyWith(
            message: _messageController.text.trim(),
            zone: _zoneController.text.trim(),
            // Update expiresAt based on new duration from NOW
            expiresAt: DateTime.now().add(Duration(hours: _durationInHours)),
          );

          await ref.read(nextdoorControllerProvider.notifier).updateAnnouncement(
                updatedAnnouncement,
                newImage: _imageFile,
                latitude: _latitude,
                longitude: _longitude,
              );
          
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Annuncio aggiornato!')),
            );
          }
        } else {
          await ref.read(nextdoorControllerProvider.notifier).createAnnouncement(
                message: _messageController.text.trim(),
                zone: _zoneController.text.trim(),
                durationInHours: _durationInHours,
                imageFile: _imageFile,
                latitude: _latitude,
                longitude: _longitude,
              );
          
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Annuncio pubblicato!')),
            );
          }
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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextdoorState = ref.watch(nextdoorControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifica Annuncio' : 'Nuovo Annuncio'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? 'Modifica il tuo annuncio' : 'Condividi qualcosa con il vicinato',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Avvisi, eventi, o semplici saluti. Il tuo messaggio sarà visibile a chi si trova nelle vicinanze.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 32),

              // Image Picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                    image: _imageFile != null
                        ? DecorationImage(
                            image: FileImage(_imageFile!),
                            fit: BoxFit.cover,
                          )
                        : (_isEditing && widget.announcementToEdit?.imageUrl != null)
                            ? DecorationImage(
                                image: NetworkImage(widget.announcementToEdit!.imageUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                    border: Border.all(
                      color: AppColors.textSecondary.withOpacity(0.2),
                    ),
                  ),
                  child: (_imageFile == null && (!_isEditing || widget.announcementToEdit?.imageUrl == null))
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_a_photo,
                                size: 48, color: AppColors.textSecondary),
                            const SizedBox(height: 8),
                            Text(
                              'Aggiungi una foto',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                          ],
                        )
                      : Stack(
                          children: [
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _imageFile = null;
                                    // Note: We can't easily remove existing network image without a separate flag
                                    // For now, this just clears the newly picked image
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // Message
              TextFormField(
                controller: _messageController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Messaggio',
                  alignLabelWithHint: true,
                  hintText: 'Es. Ho trovato un cane smarrito in via Roma...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Inserisci un messaggio' : null,
              ),
              const SizedBox(height: 24),

              // Zone / Location
              AddressAutocompleteField(
                controller: _zoneController,
                label: 'Zona / Indirizzo',
                initialValue: _zoneController.text,
                onSelected: (place) {
                  setState(() {
                    _latitude = place.latitude;
                    _longitude = place.longitude;
                    // Address is already updated in controller by the widget
                  });
                },
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Inserisci la zona' : null,
              ),
              const SizedBox(height: 24),

              // Duration
              Text('Durata annuncio', style: Theme.of(context).textTheme.titleSmall),
              Slider(
                value: _durationInHours.toDouble(),
                min: 1,
                max: 48,
                divisions: 47,
                label: '$_durationInHours ore',
                onChanged: (value) {
                  setState(() => _durationInHours = value.round());
                },
              ),
              Center(child: Text('Visibile per $_durationInHours ore')),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: nextdoorState.isSubmitting ? null : _handleSubmit,
                  child: nextdoorState.isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isEditing ? 'Aggiorna Annuncio' : 'Pubblica Annuncio'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
