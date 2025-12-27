import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../../../../features/ads/presentation/widgets/unified_ad_card.dart'; // Provider
import '../../../../shared/models/ad_campaign_model.dart'; // Model
import '../../../../core/theme/app_colors.dart';

class CreateCampaignScreen extends ConsumerStatefulWidget {
  const CreateCampaignScreen({super.key});

  @override
  ConsumerState<CreateCampaignScreen> createState() => _CreateCampaignScreenState();
}

class _CreateCampaignScreenState extends ConsumerState<CreateCampaignScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _linkController = TextEditingController();
  
  // State
  String _selectedZone = 'nextdoor_feed'; // Default
  String? _uploadedImageUrl;
  Uint8List? _localImageBytes;
  bool _isUploading = false;
  
  final _zones = [
    {'value': 'nextdoor_feed', 'label': 'Nextdoor Feed (Every 5 posts)'},
    {'value': 'activities_list', 'label': 'Activities List (Every 8 items)'},
    {'value': 'global', 'label': 'Global Fallback'},
  ];

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _localImageBytes = bytes;
        _uploadedImageUrl = null; // Reset until uploaded
      });
      _uploadImage(bytes, image.name);
    }
  }

  Future<void> _uploadImage(Uint8List bytes, String name) async {
    setState(() => _isUploading = true);
    try {
      final url = await ref.read(adServiceProvider).uploadAdImage(bytes, '${const Uuid().v4()}_$name');
      setState(() {
        _uploadedImageUrl = url;
        _isUploading = false;
      });
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore upload: $e')));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_uploadedImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Devi caricare un\'immagine')));
      return;
    }

    final ad = AdCampaignModel(
      id: '', // Firestore will generate? No, we use .add() so it's auto-generated, wait model expects ID.
      // Actually .add() creates ID. We should probably use .doc().set() if we want to control ID, or let Firestore generate.
      // But our model constructor requires ID. 
      // Workaround: We pass empty ID here, and if using .add(), Firestore ignores the ID field inside map unless we explicitly assume it match doc ID logic.
      // Usually better to let Firestore generate.
      // Or:
      // id: const Uuid().v4(), -> and store it.
      // Let's rely on .add() provided by Service which uses .add(ad.toMap()).
      // So the ID in the document FIELDS might be different from Document ID if we pass empty.
      // Correct approach: Service .createCampaign uses .add().
      // That's fine.
      businessId: 'admin', // For now
      title: _titleController.text,
      body: _bodyController.text,
      imageUrl: _uploadedImageUrl!,
      ctaText: 'Scopri',
      ctaLink: _linkController.text,
      targetZone: _selectedZone,
      isActive: true,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 30)), // Default 30 days
    );

    try {
      await ref.read(adServiceProvider).createCampaign(ad);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Campagna creata!')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore salvataggio: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuova Campagna'), elevation: 1),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Form
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Dettagli Annuncio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    
                    // Zone Selector
                    DropdownButtonFormField<String>(
                      initialValue: _selectedZone,
                      decoration: const InputDecoration(labelText: 'Posizionamento (Zone)', border: OutlineInputBorder()),
                      items: _zones.map((z) => DropdownMenuItem(value: z['value'], child: Text(z['label']!))).toList(),
                      onChanged: (v) => setState(() => _selectedZone = v!),
                    ),
                    const SizedBox(height: 16),
                    
                    // Title
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Titolo (Max 25 caratteri)', border: OutlineInputBorder()),
                      maxLength: 25,
                      validator: (v) => v!.isEmpty ? 'Richiesto' : null,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    
                    // Body
                    TextFormField(
                      controller: _bodyController,
                      decoration: const InputDecoration(labelText: 'Testo (Max 90 caratteri)', border: OutlineInputBorder()),
                      maxLength: 90,
                      maxLines: 2,
                      validator: (v) => v!.isEmpty ? 'Richiesto' : null,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Link
                    TextFormField(
                      controller: _linkController,
                      decoration: const InputDecoration(labelText: 'Link Destinazione (es. https://...)', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'Richiesto' : null,
                    ),
                    const SizedBox(height: 24),

                    // Image Picker
                    const Text('Immagine Creativa (Square/Rect)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickImage,
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _localImageBytes != null
                            ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(_localImageBytes!, fit: BoxFit.cover))
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey),
                                  Text('Clicca per caricare', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                      ),
                    ),
                    if (_isUploading) const LinearProgressIndicator(),

                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _submit,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                        child: const Text('PUBBLICA CAMPAGNA'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const VerticalDivider(width: 1),

          // Right: Preview
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey[50],
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                   const Text('Anteprima Live', style: TextStyle(color: Colors.grey)),
                   const SizedBox(height: 24),
                   // Simulating the UnifiedAdCard UI manually or using a mockup because we can't easily instantiate UnifiedAdCard with mock data without mocking the Service 
                   // Actually, we can just build the UI similar to _buildProprietaryAd logic.
                   Container(
                     width: 300, // Mobile width sim
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)]),
                     child: Column(
                       children: [
                         const ListTile(
                           leading: CircleAvatar(child: Icon(Icons.person)),
                           title: Text('Post Utente'),
                           subtitle: Text('2 min fa'),
                         ),
                         const SizedBox(height: 16),
                         // THE AD
                         Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.only(topLeft: Radius.circular(11), bottomRight: Radius.circular(11)),
                                ),
                                child: const Text('Sponsorizzato', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                     ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: _localImageBytes != null 
                                          ? Image.memory(_localImageBytes!, width: 60, height: 60, fit: BoxFit.cover)
                                          : Container(width: 60, height: 60, color: Colors.grey[200], child: const Icon(Icons.image)),
                                      ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(_titleController.text.isEmpty ? 'Titolo Qui' : _titleController.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          const SizedBox(height: 4),
                                          Text(_bodyController.text.isEmpty ? 'Testo della pubblicità...' : _bodyController.text, style: TextStyle(color: Colors.grey[600], fontSize: 13), maxLines: 2),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () {},
                                    child: const Text('SCOPRI'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                         const SizedBox(height: 16),
                         const ListTile(
                           leading: CircleAvatar(child: Icon(Icons.person)),
                           title: Text('Altro Post'),
                           subtitle: Text('5 min fa'),
                         ),
                       ],
                     ),
                   ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
