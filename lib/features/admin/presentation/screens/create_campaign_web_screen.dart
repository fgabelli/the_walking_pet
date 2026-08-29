import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../../../../features/ads/presentation/widgets/unified_ad_card.dart'; // Provider
import '../../../../shared/models/ad_campaign_model.dart'; // Model
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/osm_service.dart';

class CreateCampaignScreen extends ConsumerStatefulWidget {
  final String? prefillBusinessName;
  final String? prefillCity;
  final AdCampaignModel? adToEdit;

  const CreateCampaignScreen({
    super.key,
    this.prefillBusinessName,
    this.prefillCity,
    this.adToEdit,
  });

  @override
  ConsumerState<CreateCampaignScreen> createState() => _CreateCampaignScreenState();
}

class _CreateCampaignScreenState extends ConsumerState<CreateCampaignScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late final TextEditingController _titleController;
  final _bodyController = TextEditingController();
  final _linkController = TextEditingController();
  
  // Targeting Controllers & State
  String _targetingType = 'national';
  final _regionController = TextEditingController();
  final _cityController = TextEditingController();
  final _radiusController = TextEditingController(text: '10.0');
  double? _targetLatitude;
  double? _targetLongitude;

  @override
  void initState() {
    super.initState();
    
    if (widget.adToEdit != null) {
      final ad = widget.adToEdit!;
      _titleController = TextEditingController(text: ad.title);
      _bodyController.text = ad.body;
      _linkController.text = ad.ctaLink;
      _selectedZone = ad.targetZone;
      _uploadedImageUrl = ad.imageUrl;
      _uploadedVideoUrl = ad.videoUrl;
      _startDate = ad.startDate;
      _endDate = ad.endDate;
      _targetingType = ad.targetingType;
      _regionController.text = ad.targetRegion ?? '';
      _cityController.text = ad.targetCity ?? '';
      _radiusController.text = ad.targetRadiusKm?.toString() ?? '10.0';
      _targetLatitude = ad.targetLatitude;
      _targetLongitude = ad.targetLongitude;
    } else {
      _titleController = TextEditingController(text: widget.prefillBusinessName);
      if (widget.prefillCity != null) {
        _bodyController.text = 'Apertura a ${widget.prefillCity}';
        _cityController.text = widget.prefillCity!;
        _targetingType = 'local';
        _radiusController.text = '10.0';
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _linkController.dispose();
    _regionController.dispose();
    _cityController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  // State
  String _selectedZone = 'nextdoor_feed'; // Default
  String? _uploadedImageUrl;
  String? _uploadedVideoUrl;
  Uint8List? _localImageBytes;
  Uint8List? _localVideoBytes;
  bool _isUploading = false;
  bool _isUploadingVideo = false;
  
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  
  final _zones = [
    {'value': 'nextdoor_feed', 'label': 'Feed Mappa Vicinato (Ogni 5 post)'},
    {'value': 'activities_list', 'label': 'Lista Attività (Ogni 8 elementi)'},
    {'value': 'social_feed', 'label': 'Feed Social / Per Te (Ogni 5 post)'},
    {'value': 'dating_deck', 'label': 'Dating Swipe Deck (Ogni 5 swipe)'},
    {'value': 'reels_feed', 'label': 'Feed Reels (Ogni 5 video - solo video)'},
    {'value': 'global', 'label': 'Fallback Globale'},
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore upload immagine: $e')));
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    
    if (video != null) {
      final bytes = await video.readAsBytes();
      setState(() {
        _localVideoBytes = bytes;
        _uploadedVideoUrl = null; // Reset until uploaded
      });
      _uploadVideo(bytes, video.name);
    }
  }

  Future<void> _uploadVideo(Uint8List bytes, String name) async {
    setState(() => _isUploadingVideo = true);
    try {
      final url = await ref.read(adServiceProvider).uploadAdVideo(bytes, '${const Uuid().v4()}_$name');
      setState(() {
        _uploadedVideoUrl = url;
        _isUploadingVideo = false;
      });
    } catch (e) {
      setState(() => _isUploadingVideo = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore upload video: $e')));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_uploadedImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Devi caricare un\'immagine copertina')));
      return;
    }
    if (_selectedZone == 'reels_feed' && _uploadedVideoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Devi caricare un video promozionale per il posizionamento Reels')));
      return;
    }

    double? lat = _targetLatitude;
    double? lon = _targetLongitude;
    double? radius = _targetingType == 'local' ? double.tryParse(_radiusController.text) : null;

    if (_targetingType == 'local') {
      final cityName = _cityController.text.trim();
      if (cityName.isNotEmpty) {
        // If the city name has changed compared to the original, or coordinates are null, geocode it
        if (widget.adToEdit == null || widget.adToEdit!.targetCity != cityName || lat == null || lon == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Risoluzione coordinate geografiche in corso...'),
            duration: Duration(seconds: 2),
          ));
          try {
            final places = await OSMService().searchAddress(cityName);
            if (places.isNotEmpty) {
              lat = places.first.latitude;
              lon = places.first.longitude;
            }
          } catch (e) {
            debugPrint('Error geocoding target city: $e');
          }
        }
      }
    }

    final ad = AdCampaignModel(
      id: widget.adToEdit?.id ?? '', 
      businessId: widget.adToEdit?.businessId ?? 'admin', 
      title: _titleController.text,
      body: _bodyController.text,
      imageUrl: _uploadedImageUrl!,
      videoUrl: _uploadedVideoUrl,
      ctaText: widget.adToEdit?.ctaText ?? 'Scopri',
      ctaLink: _linkController.text,
      targetZone: _selectedZone,
      isActive: widget.adToEdit?.isActive ?? true,
      startDate: _startDate,
      endDate: _endDate,
      createdAt: widget.adToEdit?.createdAt ?? DateTime.now(),
      impressions: widget.adToEdit?.impressions ?? 0,
      clicks: widget.adToEdit?.clicks ?? 0,
      targetingType: _targetingType,
      targetRegion: _targetingType == 'regional' ? _regionController.text.trim() : null,
      targetCity: _targetingType == 'local' ? _cityController.text.trim() : null,
      targetLatitude: lat,
      targetLongitude: lon,
      targetRadiusKm: radius,
    );

    try {
      if (widget.adToEdit != null) {
        await ref.read(adServiceProvider).updateCampaign(ad);
      } else {
        await ref.read(adServiceProvider).createCampaign(ad);
      }
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(widget.adToEdit != null ? 'Campagna aggiornata!' : 'Campagna creata!')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore salvataggio: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.adToEdit != null ? 'Modifica Campagna' : 'Nuova Campagna'), elevation: 1),
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
                    
                    // Date Pickers
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _startDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setState(() {
                                  _startDate = picked;
                                  if (_endDate.isBefore(_startDate)) {
                                    _endDate = _startDate.add(const Duration(days: 1));
                                  }
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Data Inizio', border: OutlineInputBorder()),
                              child: Text('${_startDate.day}/${_startDate.month}/${_startDate.year}'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _endDate,
                                firstDate: _startDate,
                                lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                              );
                              if (picked != null) setState(() => _endDate = picked);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Data Fine', border: OutlineInputBorder()),
                              child: Text('${_endDate.day}/${_endDate.month}/${_endDate.year}'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Zone Selector
                    DropdownButtonFormField<String>(
                      initialValue: _selectedZone,
                      decoration: const InputDecoration(labelText: 'Posizionamento (Zone)', border: OutlineInputBorder()),
                      items: _zones.map((z) => DropdownMenuItem(value: z['value'], child: Text(z['label']!))).toList(),
                      onChanged: (v) => setState(() => _selectedZone = v!),
                    ),
                    _buildZoneDescriptionCard(),
                    
                    // Targeting Selector
                    const SizedBox(height: 12),
                    const Text('Targetizzazione Geografica', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _targetingType,
                      decoration: const InputDecoration(labelText: 'Target Geografico', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'national', child: Text('Tutta Italia (Nazionale)')),
                        DropdownMenuItem(value: 'regional', child: Text('Regionale (Solo una Regione)')),
                        DropdownMenuItem(value: 'local', child: Text('Locale (Città + Raggio)')),
                      ],
                      onChanged: (v) => setState(() => _targetingType = v!),
                    ),
                    if (_targetingType == 'regional') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _regionController,
                        decoration: const InputDecoration(
                          labelText: 'Regione Target (es. Lombardia, Sicilia)',
                          border: OutlineInputBorder(),
                          helperText: 'Inserisci il nome esatto della regione italiana',
                        ),
                        validator: (v) => _targetingType == 'regional' && v!.trim().isEmpty ? 'Specifica la regione' : null,
                      ),
                    ],
                    if (_targetingType == 'local') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(
                          labelText: 'Città Target (es. Lissone, Palermo)',
                          border: OutlineInputBorder(),
                          helperText: 'Inserisci il nome esatto del comune italiano',
                        ),
                        validator: (v) => _targetingType == 'local' && v!.trim().isEmpty ? 'Specifica la città' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _radiusController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Raggio di Copertura (in km)',
                          border: OutlineInputBorder(),
                          helperText: 'Inserisci la distanza massima di copertura in km (es. 10.0)',
                        ),
                        validator: (v) {
                          if (_targetingType != 'local') return null;
                          if (v == null || v.trim().isEmpty) return 'Specifica il raggio';
                          final val = double.tryParse(v);
                          if (val == null || val <= 0) return 'Inserisci un raggio valido (maggiore di 0)';
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                    
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
                    const Text('Immagine Copertina / Immagine Creativa (Obbligatoria)', style: TextStyle(fontWeight: FontWeight.bold)),
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
                            : _uploadedImageUrl != null 
                                ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(_uploadedImageUrl!, fit: BoxFit.cover))
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey),
                                      Text('Clicca per caricare immagine', style: TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                      ),
                    ),
                    if (_isUploading) const LinearProgressIndicator(),

                    const SizedBox(height: 24),

                    // Video Picker (Optional)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Video Promozionale / Reel (Opzionale)', style: TextStyle(fontWeight: FontWeight.bold)),
                        if (_uploadedVideoUrl != null)
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _uploadedVideoUrl = null;
                                _localVideoBytes = null;
                              });
                            },
                            icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                            label: const Text('Rimuovi', style: TextStyle(color: Colors.red, fontSize: 12)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickVideo,
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _localVideoBytes != null || _uploadedVideoUrl != null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.green, size: 36),
                                  const SizedBox(height: 8),
                                  Text(
                                    _uploadedVideoUrl != null ? 'Video caricato online' : 'Video pronto per l\'upload',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text('Clicca per cambiare video', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.video_call, size: 40, color: Colors.grey),
                                  Text('Carica un video per post stile Reel', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                      ),
                    ),
                    if (_isUploadingVideo) const LinearProgressIndicator(),

                    const SizedBox(height: 24),
                    // Specifiche delle creatività per la rivendita
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.photo_filter, size: 20, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text(
                                'Guida Specifiche Tecniche Clienti',
                                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Riferisci al cliente queste specifiche in base al posizionamento scelto:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 8),
                          _buildSpecRow('Social Feed & Nextdoor Feed', 'Formato Quadrato 1:1\nRisoluzione consigliata: 1080x1080px (Max 5MB)'),
                          const Divider(height: 12),
                          _buildSpecRow('Dating Swipe Deck (Tinder)', 'Formato Verticale 9:16\nRisoluzione consigliata: 1080x1920px (Max 8MB)'),
                          const Divider(height: 12),
                          _buildSpecRow('Social Reels / Video Feed (Reel)', 'Formato Verticale 9:16 o Quadrato 1:1\nCodec H.264 (MP4/MOV) - Max 30 secondi (Max 15MB)'),
                          const Divider(height: 12),
                          _buildSpecRow('Activities List & Global', 'Formato Quadrato (1:1) o Rettangolare (16:9)\nConsigliato: 1080x1080px o 1200x630px'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _submit,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                        child: Text(widget.adToEdit != null ? 'SALVA MODIFICHE' : 'PUBBLICA CAMPAGNA'),
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
                                          : _uploadedImageUrl != null 
                                              ? Image.network(_uploadedImageUrl!, width: 60, height: 60, fit: BoxFit.cover)
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

  Widget _buildSpecRow(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
          ),
          const SizedBox(height: 2),
          Text(
            desc,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneDescriptionCard() {
    String title = '';
    String description = '';
    String frequency = '';
    String recommendedFormat = '';
    IconData icon = Icons.info_outline;

    switch (_selectedZone) {
      case 'nextdoor_feed':
        title = 'Feed Mappa Vicinato';
        description = 'L\'annuncio viene inserito direttamente nel feed locale dei post geolocalizzati (scheda Mappa). Si integra visivamente come un post nativo.';
        frequency = '1 annuncio ogni 5 post organici.';
        recommendedFormat = 'Immagine quadrata (1:1) o video breve (1:1).';
        icon = Icons.map_outlined;
        break;
      case 'activities_list':
        title = 'Lista Attività';
        description = 'L\'annuncio appare tra gli eventi locali, le passeggiate di gruppo e i servizi proposti nella scheda Attività.';
        frequency = '1 annuncio ogni 8 elementi della lista.';
        recommendedFormat = 'Immagine rettangolare (16:9) o quadrata (1:1).';
        icon = Icons.local_activity_outlined;
        break;
      case 'social_feed':
        title = 'Feed Social / Per Te';
        description = 'L\'annuncio si inserisce all\'interno del feed social (stile Instagram) in mezzo ai post e ai reel degli utenti.';
        frequency = '1 annuncio ogni 5 post o reel.';
        recommendedFormat = 'Immagine quadrata (1:1) o video Reel verticale (9:16) / quadrato (1:1).';
        icon = Icons.share_outlined;
        break;
      case 'dating_deck':
        title = 'Dating Swipe Deck';
        description = 'L\'annuncio viene proposto come una card pubblicitaria a schermo intero nel mazzo del Dating (stile Tinder). L\'utente la visualizza e la scarta effettuando uno swipe a destra o sinistra.';
        frequency = '1 annuncio ogni 5 swipe effettuati.';
        recommendedFormat = 'Immagine verticale (9:16) o video verticale (9:16) a schermo intero.';
        icon = Icons.favorite_border;
        break;
      case 'global':
        title = 'Fallback Globale';
        description = 'Questa è una campagna di riserva. Verrà mostrata automaticamente in qualsiasi sezione dell\'app qualora non ci fossero campagne pubblicitarie specifiche attive per quella zona in quel momento.';
        frequency = 'Variabile (utilizzato come riempitivo).';
        recommendedFormat = 'Immagine quadrata (1:1) o rettangolare generica.';
        icon = Icons.public;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Focus Posizionamento: $title',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.4),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
              children: [
                const TextSpan(text: '• Frequenza in App: ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: frequency),
              ],
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
              children: [
                const TextSpan(text: '• Formato Consigliato: ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: recommendedFormat),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
