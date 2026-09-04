import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/dog_model.dart';
import '../../../../shared/models/announcement_model.dart';
import '../../../walking/presentation/screens/pet_walk_card_screen.dart';
import '../../../health_record/presentation/screens/health_record_list_screen.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/sos_service.dart';
import '../../../nextdoor/presentation/providers/nextdoor_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../map/presentation/providers/map_provider.dart';
import '../providers/dog_provider.dart';
import '../../../../shared/presentation/widgets/sos_dialog.dart';

import 'package:cached_network_image/cached_network_image.dart';

/// Public-facing pet profile screen (Scheda Pet)
class PetProfileScreen extends ConsumerStatefulWidget {
  final DogModel dog;
  final bool isOwner;

  const PetProfileScreen({
    super.key,
    required this.dog,
    this.isOwner = false,
  });

  @override
  ConsumerState<PetProfileScreen> createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends ConsumerState<PetProfileScreen> {
  int _heroPage = 0;

  DogModel get dog => widget.dog;
  bool get isOwner => widget.isOwner;

  List<String> get _photos {
    if (dog.mediaUrls.isNotEmpty) return dog.mediaUrls;
    if (dog.photoUrl != null && dog.photoUrl!.isNotEmpty) return [dog.photoUrl!];
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // Hero image with sliver app bar + share action
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              // Share button always visible
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.share, color: Colors.white, size: 20),
                ),
                onPressed: () => _sharePetCard(context),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _photos.isEmpty
                  ? Container(
                      color: AppColors.primary.withOpacity(0.2),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.pets, size: 80, color: Colors.white54),
                            const SizedBox(height: 12),
                            Text(dog.name,
                              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        // Photo(s)
                        if (_photos.length == 1)
                          CachedNetworkImage(
                            imageUrl: _photos.first,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: AppColors.primary.withOpacity(0.2),
                              child: const Center(child: Icon(Icons.pets, size: 80, color: Colors.white54)),
                            ),
                          )
                        else
                          PageView.builder(
                            itemCount: _photos.length,
                            onPageChanged: (i) => setState(() => _heroPage = i),
                            itemBuilder: (context, index) {
                              return CachedNetworkImage(
                                imageUrl: _photos[index],
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  color: AppColors.primary.withOpacity(0.2),
                                  child: const Center(child: Icon(Icons.pets, size: 80, color: Colors.white54)),
                                ),
                              );
                            },
                          ),

                        // Photo indicators (top)
                        if (_photos.length > 1)
                          Positioned(
                            top: MediaQuery.of(context).padding.top + 48,
                            left: 16,
                            right: 16,
                            child: Row(
                              children: List.generate(_photos.length, (i) {
                                return Expanded(
                                  child: Container(
                                    height: 3,
                                    margin: const EdgeInsets.symmetric(horizontal: 2),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(2),
                                      color: i == _heroPage ? Colors.white : Colors.white.withOpacity(0.35),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),

                        // Gradient overlay
                        Positioned(
                          bottom: 0, left: 0, right: 0,
                          child: Container(
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                              ),
                            ),
                          ),
                        ),
                        // Name overlay
                        Positioned(
                          bottom: 16, left: 20, right: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      dog.name,
                                      style: const TextStyle(
                                        color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800,
                                        shadows: [Shadow(color: Colors.black45, blurRadius: 8)],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white.withOpacity(0.4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          dog.species == PetSpecies.cat ? Icons.emoji_nature : Icons.pets,
                                          color: Colors.white, size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(dog.species.displayName,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(dog.breed,
                                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Grid
                  _buildInfoGrid(context),
                  const SizedBox(height: 24),

                  // Character Traits
                  if (dog.character.isNotEmpty) ...[
                    _buildSectionTitle(context, Icons.favorite, 'Carattere'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: dog.character.map((trait) => _CharacterChip(label: trait)).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Medical Info
                  if (_hasMedicalInfo()) ...[
                    _buildSectionTitle(context, Icons.medical_services, 'Info Sanitarie'),
                    const SizedBox(height: 12),
                    _buildMedicalCard(context),
                    const SizedBox(height: 24),
                  ],

                  // Notes
                  if (dog.notes != null && dog.notes!.isNotEmpty) ...[
                    _buildSectionTitle(context, Icons.notes, 'Note'),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(dog.notes!, style: const TextStyle(fontSize: 15, height: 1.5)),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // === OWNER ACTIONS ===
                  if (isOwner) ...[
                    const Divider(height: 32),

                    // Walk Card
                    _ActionButton(
                      icon: Icons.directions_walk,
                      label: 'Walk Card & Statistiche',
                      subtitle: 'Visualizza i progressi delle passeggiate',
                      color: Colors.blueAccent,
                      onTap: () {
                         Navigator.of(context).push(
                           MaterialPageRoute(
            settings: const RouteSettings(name: 'pet_walk_card'),
                             builder: (_) => PetWalkCardScreen(pet: dog),
                           ),
                         );
                      },
                    ),
                    const SizedBox(height: 12),

                    // Libretto Sanitario
                    _ActionButton(
                      icon: Icons.medical_services,
                      label: 'Libretto Sanitario',
                      subtitle: 'Vaccini, trattamenti e archivio medico',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
            settings: const RouteSettings(name: 'health_record_list'),
                            builder: (_) => HealthRecordListScreen(
                              dog: dog,
                              isOwner: true,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // Share Pet Card
                    _ActionButton(
                      icon: Icons.share,
                      label: 'Condividi sui Social',
                      subtitle: 'WhatsApp, Instagram, Facebook...',
                      color: AppColors.accent,
                      onTap: () => _sharePetCard(context),
                    ),
                    const SizedBox(height: 12),

                    // Adoption CTA
                    _ActionButton(
                      icon: Icons.volunteer_activism,
                      label: 'Cerca una Famiglia 🏡',
                      subtitle: 'Pubblica un annuncio di adozione',
                      color: Colors.teal,
                      onTap: () => _showAdoptionFlow(context),
                    ),
                    const SizedBox(height: 16),

                    // SOS Button — full width, red, prominent
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          foregroundColor: Colors.red,
                          elevation: 0,
                          side: BorderSide(color: Colors.red.shade200),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => showSOSDialog(context, ref, dog),
                        icon: const Icon(Icons.sos, size: 28),
                        label: const Column(
                          children: [
                            Text('PET SMARRITO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            SizedBox(height: 2),
                            Text('Segnala smarrimento alla community', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }



  void _sharePetCard(BuildContext context) {
    final emoji = dog.species == PetSpecies.cat ? '🐱' : '🐶';
    final text = '$emoji Conosci ${dog.name}!\n\n'
        '🐾 ${dog.breed} • ${dog.age} anni • ${dog.size.displayName}\n'
        '${dog.gender == DogGender.male ? '♂️ Maschio' : '♀️ Femmina'}\n'
        '${dog.character.isNotEmpty ? '❤️ ${dog.character.join(", ")}\n' : ''}'
        '\nScarica DOGZN per conoscere ${dog.name} e tanti altri amici a 4 zampe!\n'
        '📲 https://dogzn.com';

    final box = context.findRenderObject() as RenderBox?;
    final rect = box != null ? box.localToGlobal(Offset.zero) & box.size : null;

    Share.share(text, sharePositionOrigin: rect);
  }



  // === ADOPTION FLOW ===
  void _showAdoptionFlow(BuildContext context) {
    final messageController = TextEditingController();
    final phoneController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Cerca una Famiglia per il tuo Pet 🏡',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Pubblicheremo un annuncio sulla bacheca DOGZN e potrai condividerlo anche sui social.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Pet preview card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.teal.shade100),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: dog.photoUrl != null ? NetworkImage(dog.photoUrl!) : null,
                        backgroundColor: Colors.teal.shade100,
                        child: dog.photoUrl == null
                            ? Icon(Icons.pets, color: Colors.teal.shade700)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(dog.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            Text(
                              '${dog.breed} • ${dog.age} anni • ${dog.size.displayName}',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Message
                TextField(
                  controller: messageController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Racconta di ${dog.name}',
                    hintText: 'Perché cerchi una famiglia? Carattere, abitudini, requisiti...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 16),

                // Phone
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Contatto telefonico',
                    hintText: 'Per chi vuole adottare',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 24),

                // Publish on DOGZN bacheca
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.campaign),
                  label: const Text('Pubblica sulla Bacheca DOGZN', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  onPressed: () => _publishAdoption(context, messageController.text, phoneController.text),
                ),
                const SizedBox(height: 12),

                // Share on social
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(color: AppColors.accent.withOpacity(0.5)),
                  ),
                  icon: const Icon(Icons.share),
                  label: const Text('Condividi anche sui Social', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  onPressed: () {
                    Navigator.pop(context);
                    _shareAdoptionCard(context, messageController.text, phoneController.text);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _publishAdoption(BuildContext context, String message, String phone) async {
    final emoji = dog.species == PetSpecies.cat ? '🐱' : '🐶';
    final fullMessage = '$emoji ADOZIONE: ${dog.name}\n'
        '${dog.breed} • ${dog.age} anni • ${dog.gender.displayName} • ${dog.size.displayName}\n'
        '${dog.character.isNotEmpty ? '❤️ ${dog.character.join(", ")}\n' : ''}'
        '${message.isNotEmpty ? '\n$message\n' : ''}'
        '${phone.isNotEmpty ? '\n📞 Contatto: $phone' : ''}';

    try {
      await ref.read(nextdoorControllerProvider.notifier).createAnnouncement(
        message: fullMessage,
        zone: 'Adozione',
        durationInHours: 168, // 7 days
        category: AnnouncementCategory.adoption,
        imageUrl: dog.photoUrl,
      );

      if (context.mounted) {
        Navigator.pop(context); // Close bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Annuncio di adozione pubblicato sulla bacheca!'),
            backgroundColor: Colors.teal,
          ),
        );

        // Ask to share on social too
        _showShareSocialPrompt(context, message, phone);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
  }

  void _showShareSocialPrompt(BuildContext context, String message, String phone) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('📢 Condividi anche fuori!'),
        content: const Text(
          'Vuoi condividere l\'annuncio anche su WhatsApp, Instagram o Facebook per raggiungere più persone?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No, grazie'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Condividi'),
            onPressed: () {
              Navigator.pop(context);
              _shareAdoptionCard(context, message, phone);
            },
          ),
        ],
      ),
    );
  }

  void _shareAdoptionCard(BuildContext context, String message, String phone) {
    final emoji = dog.species == PetSpecies.cat ? '🐱' : '🐶';
    final text = '🏡 $emoji CERCO UNA FAMIGLIA PER ${dog.name.toUpperCase()}!\n\n'
        '🐾 ${dog.breed}\n'
        '📅 ${dog.age} anni\n'
        '${dog.gender == DogGender.male ? '♂️ Maschio' : '♀️ Femmina'} • ${dog.size.displayName}\n'
        '${dog.character.isNotEmpty ? '❤️ ${dog.character.join(", ")}\n' : ''}'
        '${message.isNotEmpty ? '\n$message\n' : ''}'
        '${phone.isNotEmpty ? '\n📞 $phone\n' : ''}'
        '\n👉 Scarica DOGZN per contattarmi!\n'
        '📲 https://dogzn.com';

    final box = context.findRenderObject() as RenderBox?;
    final rect = box != null ? box.localToGlobal(Offset.zero) & box.size : null;

    Share.share(text, sharePositionOrigin: rect);
  }

  // === UI HELPERS ===
  Widget _buildSectionTitle(BuildContext context, IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.accent),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildInfoGrid(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          _InfoTile(icon: Icons.cake, label: 'Età', value: '${dog.age} anni'),
          _divider(),
          _InfoTile(
            icon: dog.gender == DogGender.male ? Icons.male : Icons.female,
            label: 'Genere', value: dog.gender.displayName,
            iconColor: dog.gender == DogGender.male ? Colors.blue : Colors.pink,
          ),
          _divider(),
          _InfoTile(icon: Icons.straighten, label: 'Taglia', value: dog.size.displayName),
          if (dog.weight != null) ...[
            _divider(),
            _InfoTile(icon: Icons.monitor_weight_outlined, label: 'Peso', value: '${dog.weight!.toStringAsFixed(1)}kg'),
          ],
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(height: 40, width: 1, margin: const EdgeInsets.symmetric(horizontal: 4), color: Colors.grey.shade200);
  }

  bool _hasMedicalInfo() {
    return dog.microchipNumber != null || dog.bloodType != null ||
        dog.allergies.isNotEmpty || dog.intolerances.isNotEmpty || dog.pathologies.isNotEmpty ||
        dog.isSterilized;
  }

  Widget _buildMedicalCard(BuildContext context) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dog.microchipNumber != null) _MedicalRow(icon: Icons.memory, label: 'Microchip', value: dog.microchipNumber!),
          if (dog.bloodType != null) _MedicalRow(icon: Icons.bloodtype, label: 'Gruppo Sanguigno', value: dog.bloodType!),
          if (dog.allergies.isNotEmpty) _MedicalRow(icon: Icons.warning_amber, label: 'Allergie', value: dog.allergies.join(', ')),
          if (dog.intolerances.isNotEmpty) _MedicalRow(icon: Icons.no_food, label: 'Intolleranze', value: dog.intolerances.join(', ')),
          if (dog.pathologies.isNotEmpty) _MedicalRow(icon: Icons.local_hospital, label: 'Patologie', value: dog.pathologies.join(', ')),
          if (dog.isSterilized) _MedicalRow(
            icon: dog.gender == DogGender.male ? Icons.male : Icons.female,
            label: dog.gender == DogGender.male ? 'Castrato' : 'Sterilizzata',
            value: 'Sì',
          ),
        ],
      ),
    );
  }
}

/// Action button for sharing / adoption
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon, required this.label, required this.subtitle,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: color)),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  const _InfoTile({required this.icon, required this.label, required this.value, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 22, color: iconColor ?? AppColors.accent),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.textTertiary), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _CharacterChip extends StatelessWidget {
  final String label;
  const _CharacterChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accent)),
    );
  }
}

class _MedicalRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MedicalRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.blue.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.blue.shade400, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.blue.shade900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
