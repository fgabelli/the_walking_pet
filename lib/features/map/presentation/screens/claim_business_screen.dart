import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../shared/models/pet_business_model.dart';
import '../../../../core/services/pet_business_service.dart';
import '../../../../core/services/purchase_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../subscriptions/presentation/screens/paywall_screen.dart';

/// Screen for claiming a business page with ownership verification
class ClaimBusinessScreen extends ConsumerStatefulWidget {
  final PetBusinessModel business;

  const ClaimBusinessScreen({super.key, required this.business});

  @override
  ConsumerState<ClaimBusinessScreen> createState() => _ClaimBusinessScreenState();
}

class _ClaimBusinessScreenState extends ConsumerState<ClaimBusinessScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ownerNameController = TextEditingController();
  final _roleController = TextEditingController();
  final _businessEmailController = TextEditingController();
  final _pivaController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  File? _proofPhoto; // Photo of business front / official document
  bool _isSubmitting = false;
  bool _hasBusinessPro = false;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _checkBusinessProStatus();
  }

  Future<void> _checkBusinessProStatus() async {
    try {
      final info = await ref.read(purchaseServiceProvider).getCustomerInfo();
      if (info != null && mounted) {
        setState(() {
          _hasBusinessPro = ref.read(purchaseServiceProvider).isBusiness(info);
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _ownerNameController.dispose();
    _roleController.dispose();
    _businessEmailController.dispose();
    _pivaController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickProofPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Scatta foto'),
              subtitle: const Text('Fotografa l\'insegna o un documento'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Scegli dalla galleria'),
              subtitle: const Text('Seleziona un\'immagine esistente'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 1920, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() => _proofPhoto = File(picked.path));
    }
  }

  Future<void> _submitClaim() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Step 1: Check Business Pro
    if (!_hasBusinessPro) {
      final shouldBuy = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.workspace_premium, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Business Pro richiesto'),
            ],
          ),
          content: const Text(
            'Per riscattare un\'attività è necessario un abbonamento Business Pro.\n\n'
            'Vuoi attivarlo ora?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Non ora'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Attiva Business Pro'),
            ),
          ],
        ),
      );

      if (shouldBuy == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: 'paywall'),
            builder: (_) => const PaywallScreen(offeringId: 'business_pro'),
          ),
        );
        // Re-check after returning from paywall
        await _checkBusinessProStatus();
        if (!_hasBusinessPro) return; // Still no subscription
      } else {
        return;
      }
    }

    // Step 2: Submit claim
    setState(() => _isSubmitting = true);

    try {
      String? proofPhotoUrl;
      if (_proofPhoto != null) {
        final storageService = StorageService();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        proofPhotoUrl = await storageService.uploadAnnouncementImage(
          'claims/${user.uid}_$timestamp',
          _proofPhoto!,
        );
      }

      await ref.read(petBusinessServiceProvider).submitBusinessClaim(
        businessId: widget.business.id,
        businessName: widget.business.name,
        googlePlaceId: widget.business.googlePlaceId,
        userId: user.uid,
        ownerName: _ownerNameController.text.trim(),
        role: _roleController.text.trim(),
        businessEmail: _businessEmailController.text.trim(),
        piva: _pivaController.text.trim(),
        phone: _phoneController.text.trim(),
        notes: _notesController.text.trim(),
        proofPhotoUrl: proofPhotoUrl,
      );

      if (!mounted) return;

      // Show success
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Expanded(child: Text('Richiesta inviata!')),
            ],
          ),
          content: const Text(
            'La tua richiesta di riscatto è stata inviata con successo.\n\n'
            'Il nostro team verificherà le informazioni e ti notificherà '
            'quando la tua pagina sarà attiva.\n\n'
            'Tempo stimato: 24-48 ore lavorative.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true); // Return to detail with result
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ho capito'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final biz = widget.business;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Riscatta attività'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Business info header
              _buildBusinessHeader(biz, isDark),
              const SizedBox(height: 24),

              // Stepper visual
              _buildStepIndicator(),
              const SizedBox(height: 24),

              // Step content
              if (_currentStep == 0) _buildStep1OwnerInfo(isDark),
              if (_currentStep == 1) _buildStep2Verification(isDark),
              if (_currentStep == 2) _buildStep3Review(isDark),

              const SizedBox(height: 24),

              // Navigation buttons
              _buildNavigationButtons(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Business Header ──────────────────────────────────
  Widget _buildBusinessHeader(PetBusinessModel biz, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.08),
            AppColors.primary.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(biz.category.icon, style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  biz.name,
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  biz.category.displayName,
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
                Text(
                  biz.address,
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step Indicator ───────────────────────────────────
  Widget _buildStepIndicator() {
    const steps = ['Dati', 'Verifica', 'Conferma'];
    return Row(
      children: List.generate(steps.length, (i) {
        final isActive = i == _currentStep;
        final isComplete = i < _currentStep;
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isComplete
                      ? Colors.green
                      : isActive
                          ? AppColors.primary
                          : Colors.grey[300],
                ),
                child: Center(
                  child: isComplete
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : Text(
                          '${i + 1}',
                          style: TextStyle(
                            color: isActive ? Colors.white : Colors.grey[600],
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  steps[i],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? AppColors.primary : Colors.grey[500],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ─── Step 1: Owner Information ────────────────────────
  Widget _buildStep1OwnerInfo(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Informazioni proprietario',
          'Inserisci i tuoi dati come titolare o responsabile dell\'attività.',
          Icons.person_outline,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _ownerNameController,
          label: 'Nome e cognome *',
          hint: 'es. Mario Rossi',
          icon: Icons.person,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obbligatorio' : null,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _roleController,
          label: 'Ruolo *',
          hint: 'es. Titolare, Direttore, Responsabile',
          icon: Icons.badge,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obbligatorio' : null,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _phoneController,
          label: 'Telefono di contatto *',
          hint: 'es. +39 333 1234567',
          icon: Icons.phone,
          keyboardType: TextInputType.phone,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obbligatorio' : null,
        ),
      ],
    );
  }

  // ─── Step 2: Verification ─────────────────────────────
  Widget _buildStep2Verification(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Verifica proprietà',
          'Fornisci le informazioni necessarie per verificare che sei il proprietario di questa attività.',
          Icons.verified_user_outlined,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _businessEmailController,
          label: 'Email aziendale *',
          hint: 'es. info@nomenegozio.it',
          icon: Icons.email,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Campo obbligatorio';
            if (!v.contains('@') || !v.contains('.')) return 'Email non valida';
            return null;
          },
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _pivaController,
          label: 'Partita IVA *',
          hint: 'es. IT12345678901',
          icon: Icons.business,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Campo obbligatorio';
            final cleaned = v.replaceAll(RegExp(r'[^0-9]'), '');
            if (cleaned.length < 11) return 'La P.IVA deve avere almeno 11 cifre';
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Proof photo
        _buildSectionHeader(
          'Foto di verifica',
          'Scatta o carica una foto dell\'insegna del negozio, della Visura Camerale '
          'o di un altro documento che dimostri la proprietà.',
          Icons.camera_alt_outlined,
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _pickProofPhoto,
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _proofPhoto != null
                    ? Colors.green.withOpacity(0.5)
                    : Colors.grey.withOpacity(0.3),
                width: 2,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: _proofPhoto != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(_proofPhoto!, fit: BoxFit.cover),
                        Positioned(
                          top: 8, right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, color: Colors.white, size: 18),
                          ),
                        ),
                        Positioned(
                          bottom: 8, right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() => _proofPhoto = null),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, size: 40, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'Tocca per aggiungere una foto',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Insegna, Visura Camerale, documento',
                        style: TextStyle(color: Colors.grey[400], fontSize: 11),
                      ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 16),
        _buildTextField(
          controller: _notesController,
          label: 'Note aggiuntive (opzionale)',
          hint: 'Qualsiasi altra informazione utile per la verifica...',
          icon: Icons.note_alt_outlined,
          maxLines: 3,
        ),
      ],
    );
  }

  // ─── Step 3: Review & Submit ──────────────────────────
  Widget _buildStep3Review(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Riepilogo',
          'Verifica le informazioni prima di inviare la richiesta.',
          Icons.fact_check_outlined,
        ),
        const SizedBox(height: 16),
        _buildReviewCard(isDark),
        const SizedBox(height: 16),

        // Business Pro status
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _hasBusinessPro
                ? Colors.green.withOpacity(0.08)
                : Colors.orange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hasBusinessPro
                  ? Colors.green.withOpacity(0.3)
                  : Colors.orange.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _hasBusinessPro ? Icons.check_circle : Icons.info_outline,
                color: _hasBusinessPro ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hasBusinessPro
                          ? 'Business Pro attivo ✓'
                          : 'Business Pro richiesto',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _hasBusinessPro ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _hasBusinessPro
                          ? 'Sei pronto per inviare la richiesta'
                          : 'Verrà richiesto durante l\'invio',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Process info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.blue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              _buildProcessStep('1', 'Invio richiesta', 'Le tue informazioni vengono inviate'),
              _buildProcessStep('2', 'Verifica', 'Il team controlla i documenti (24-48h)'),
              _buildProcessStep('3', 'Attivazione', 'La pagina viene assegnata a te'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildReviewRow(Icons.person, 'Nome', _ownerNameController.text),
          const Divider(height: 16),
          _buildReviewRow(Icons.badge, 'Ruolo', _roleController.text),
          const Divider(height: 16),
          _buildReviewRow(Icons.phone, 'Telefono', _phoneController.text),
          const Divider(height: 16),
          _buildReviewRow(Icons.email, 'Email aziendale', _businessEmailController.text),
          const Divider(height: 16),
          _buildReviewRow(Icons.business, 'P.IVA', _pivaController.text),
          if (_proofPhoto != null) ...[
            const Divider(height: 16),
            _buildReviewRow(Icons.photo, 'Foto verifica', '✓ Allegata'),
          ],
          if (_notesController.text.trim().isNotEmpty) ...[
            const Divider(height: 16),
            _buildReviewRow(Icons.note, 'Note', _notesController.text),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[500]),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        ),
        Expanded(
          child: Text(
            value.isNotEmpty ? value : '-',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildProcessStep(String number, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.15),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Navigation Buttons ───────────────────────────────
  Widget _buildNavigationButtons() {
    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _currentStep--),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Indietro'),
            ),
          ),
        if (_currentStep > 0) const SizedBox(width: 12),
        Expanded(
          flex: _currentStep == 0 ? 1 : 1,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _onNextOrSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _currentStep == 2 ? Colors.green : AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    _currentStep == 2 ? 'Invia richiesta' : 'Avanti',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
          ),
        ),
      ],
    );
  }

  void _onNextOrSubmit() {
    if (_currentStep == 0) {
      // Validate step 1 fields
      if (_ownerNameController.text.trim().isEmpty ||
          _roleController.text.trim().isEmpty ||
          _phoneController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compila tutti i campi obbligatori')),
        );
        return;
      }
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      // Validate step 2 fields
      if (_businessEmailController.text.trim().isEmpty ||
          _pivaController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email aziendale e P.IVA sono obbligatori')),
        );
        return;
      }
      if (!_businessEmailController.text.contains('@')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inserisci un\'email valida')),
        );
        return;
      }
      setState(() => _currentStep = 2);
    } else {
      // Submit
      _submitClaim();
    }
  }

  // ─── UI Helpers ───────────────────────────────────────
  Widget _buildSectionHeader(String title, String subtitle, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        filled: true,
        fillColor: isDark ? Colors.grey[850] : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
