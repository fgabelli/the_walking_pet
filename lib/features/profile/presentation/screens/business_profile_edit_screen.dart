import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  late TextEditingController _websiteController;
  late TextEditingController _phoneController;
  String? _selectedCategory;
  bool _isLoading = false;

  final List<String> _categories = [
    'Veterinario',
    'Negozio per Animali',
    'Pet Sitter', // More inclusive than Dog Sitter
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
    _websiteController = TextEditingController(text: widget.user.website);
    _phoneController = TextEditingController(text: widget.user.phoneNumber);
    _selectedCategory = widget.user.businessCategory;
  }

  @override
  void dispose() {
    _websiteController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(profileControllerProvider.notifier).updateProfile(
        businessCategory: _selectedCategory,
        website: _websiteController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               _buildInfoCard(context),
               const SizedBox(height: 24),
               
               Text('Dettagli Attività', style: Theme.of(context).textTheme.titleLarge),
               const SizedBox(height: 16),
               
               // Category Dropdown
               DropdownButtonFormField<String>(
                 value: _selectedCategory,
                 decoration: const InputDecoration(
                   labelText: 'Categoria',
                   prefixIcon: Icon(Icons.category),
                   border: OutlineInputBorder(),
                 ),
                 items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                 onChanged: (val) => setState(() => _selectedCategory = val),
                 validator: (val) => val == null ? 'Seleziona una categoria' : null,
               ),
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
                const Text('Perché passare a Business?', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'Ottieni un indicatore speciale sulla mappa e fatti trovare dai proprietari di cani nella tua zona.',
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
