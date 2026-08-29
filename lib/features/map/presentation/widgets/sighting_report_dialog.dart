import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/sos_service.dart';
import '../../../../features/profile/presentation/providers/profile_provider.dart'; // For storageServiceProvider

class SightingReportDialog extends ConsumerStatefulWidget {
  final String alertId;
  final String petId;
  final String ownerId;
  final String finderId;
  final double latitude;
  final double longitude;

  const SightingReportDialog({
    Key? key,
    required this.alertId,
    required this.petId,
    required this.ownerId,
    required this.finderId,
    required this.latitude,
    required this.longitude,
  }) : super(key: key);

  @override
  ConsumerState<SightingReportDialog> createState() => _SightingReportDialogState();
}

class _SightingReportDialogState extends ConsumerState<SightingReportDialog> {
  final _descriptionController = TextEditingController();
  File? _pickedImageFile;
  bool _isLoading = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _pickedImageFile = File(picked.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore nella selezione dell\'immagine: $e')),
      );
    }
  }

  Future<void> _submit() async {
    final description = _descriptionController.text.trim();

    if (_pickedImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La foto dell\'avvistamento è obbligatoria per evitare segnalazioni finte!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci una descrizione dell\'animale o del punto in cui l\'hai visto!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Upload the image to Firebase Storage
      final storageService = ref.read(storageServiceProvider);
      final photoUrl = await storageService.uploadSightingImage(
        widget.alertId,
        _pickedImageFile!,
      );

      // 2. Save Sighting to Firestore
      final sosService = ref.read(sosServiceProvider);
      await sosService.addSighting(
        alertId: widget.alertId,
        petId: widget.petId,
        ownerId: widget.ownerId,
        finderId: widget.finderId,
        latitude: widget.latitude,
        longitude: widget.longitude,
        photoUrl: photoUrl,
        description: description,
      );

      if (mounted) {
        Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore nell\'invio: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.add_location_alt, color: Colors.orange, size: 28),
          SizedBox(width: 8),
          Text('Segnala Avvistamento 📍', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      content: _isLoading
          ? const SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Caricamento foto e dettagli...', style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Per garantire la massima sicurezza del proprietario ed evitare segnalazioni false, è obbligatorio allegare una foto del cane e una breve descrizione.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  
                  // Photo preview section
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: _pickedImageFile != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(_pickedImageFile!, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () => setState(() => _pickedImageFile = null),
                                  child: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.black.withOpacity(0.6),
                                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                              SizedBox(height: 8),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16.0),
                                child: Text(
                                  'Scatta o carica una foto del pet',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Buttons to choose camera/gallery
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt, size: 16),
                          label: const Text('Fotocamera', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library, size: 16),
                          label: const Text('Galleria', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Description text field
                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Descrizione dell\'avvistamento (Obbligatorio)',
                      alignLabelWithHint: true,
                      hintText: 'Es: Cane con collare rosso, correva verso la piazza principale. Sembrava impaurito.',
                      hintStyle: TextStyle(fontSize: 12),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
      actions: _isLoading
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annulla', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Invia Segnalazione'),
              ),
            ],
    );
  }
}
