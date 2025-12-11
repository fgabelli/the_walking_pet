import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/offer_model.dart';
import '../../data/offers_service.dart';
import '../../../../features/profile/presentation/providers/profile_provider.dart';

final offersServiceProvider = Provider<OffersService>((ref) => OffersService());

class CreateOfferScreen extends ConsumerStatefulWidget {
  const CreateOfferScreen({super.key});

  @override
  ConsumerState<CreateOfferScreen> createState() => _CreateOfferScreenState();
}

class _CreateOfferScreenState extends ConsumerState<CreateOfferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _codeController = TextEditingController();
  final _linkController = TextEditingController();
  final _percentageController = TextEditingController();
  
  File? _imageFile;
  OfferType _selectedType = OfferType.discountCode;
  bool _isLoading = false;
  DateTime _expirationDate = DateTime.now().add(const Duration(days: 7));

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aggiungi un\'immagine')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserProfileProvider).value;
      if (user == null) throw Exception('User not found');

      final offer = OfferModel(
        id: '', // Generated in service
        userId: user.uid,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrl: '', // Handled in service
        type: _selectedType,
        partnerName: user.businessCategory ?? 'Business', // Or user.firstName if null
        discountCode: _selectedType == OfferType.discountCode ? _codeController.text.trim() : null,
        affiliateLink: _selectedType == OfferType.externalLink ? _linkController.text.trim() : null,
        discountPercentage: _percentageController.text.isNotEmpty 
            ? double.tryParse(_percentageController.text) 
            : null,
        createdAt: DateTime.now(),
        expiresAt: _expirationDate,
      );

      await ref.read(offersServiceProvider).createOffer(offer, _imageFile);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offerta pubblicata!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crea Offerta')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    image: _imageFile != null 
                        ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _imageFile == null 
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Aggiungi Foto Offerta'),
                          ],
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Titolo Offerta', border: OutlineInputBorder()),
                validator: (v) => v?.isEmpty ?? true ? 'Inserisci un titolo' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Descrizione', border: OutlineInputBorder()),
                maxLines: 3,
                validator: (v) => v?.isEmpty ?? true ? 'Inserisci una descrizione' : null,
              ),
              const SizedBox(height: 24),

              // Offer Type Selector
              Text('Tipo di Offerta', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<OfferType>(
                segments: const [
                  ButtonSegment(value: OfferType.discountCode, label: Text('Codice Sconto')),
                  ButtonSegment(value: OfferType.externalLink, label: Text('Link Esterno')),
                ],
                selected: {_selectedType},
                onSelectionChanged: (s) => setState(() => _selectedType = s.first),
              ),
              const SizedBox(height: 16),

              if (_selectedType == OfferType.discountCode) ...[
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Codice Sconto (es. SUMMER20)', 
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.confirmation_number),
                  ),
                  validator: (v) => v?.isEmpty ?? true ? 'Inserisci il codice' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _percentageController,
                  decoration: const InputDecoration(
                    labelText: 'Percentuale Sconto (Opzionale)', 
                    border: OutlineInputBorder(),
                    suffixText: '%',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ] else ...[
                 TextFormField(
                  controller: _linkController,
                  decoration: const InputDecoration(
                    labelText: 'Link Offerta (es. https://...)', 
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                  ),
                  keyboardType: TextInputType.url,
                  validator: (v) => v?.isEmpty ?? true ? 'Inserisci il link' : null,
                ),
              ],
              
              // Expiration Date Picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Scadenza Offerta (Max 7 giorni)'),
                subtitle: Text(
                  'Scade il: ${_expirationDate.day}/${_expirationDate.month}/${_expirationDate.year}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _expirationDate,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 7)),
                  );
                  if (picked != null) {
                    setState(() => _expirationDate = picked);
                  }
                },
              ),
              const SizedBox(height: 24),
              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : const Text('Pubblica Offerta'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
