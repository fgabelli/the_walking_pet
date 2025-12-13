import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/health_service.dart';
import '../../../../shared/models/health_record_model.dart';
import '../../../../core/theme/app_colors.dart';

class AddHealthRecordScreen extends ConsumerStatefulWidget {
  final String petId;
  const AddHealthRecordScreen({super.key, required this.petId});

  @override
  ConsumerState<AddHealthRecordScreen> createState() => _AddHealthRecordScreenState();
}

class _AddHealthRecordScreenState extends ConsumerState<AddHealthRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  
  HealthRecordType _selectedType = HealthRecordType.vaccine;
  final _titleController = TextEditingController();
  final _vetController = TextEditingController();
  final _notesController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  DateTime? _nextDueDate;
  
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _vetController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isDueDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isDueDate ? (_nextDueDate ?? DateTime.now().add(const Duration(days: 365))) : _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isDueDate) {
          _nextDueDate = picked;
        } else {
          _selectedDate = picked;
        }
      });
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        final newRecord = HealthRecordModel(
          id: '', // Firestore generates this
          petId: widget.petId,
          type: _selectedType,
          title: _titleController.text,
          date: _selectedDate,
          nextDueDate: _nextDueDate,
          veterinarianName: _vetController.text,
          notes: _notesController.text,
        );

        await ref.read(healthServiceProvider).addHealthRecord(newRecord);
        if (mounted) {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aggiungi Evento Sanitario'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type Selector
              DropdownButtonFormField<HealthRecordType>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Tipo di evento',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: HealthRecordType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.displayName),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedType = val);
                },
              ),
              const SizedBox(height: 16),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titolo (es. Vaccino Rabbia)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Inserisci un titolo' : null,
              ),
              const SizedBox(height: 16),

              // Date
              InkWell(
                onTap: () => _selectDate(context, false),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data Evento',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(_selectedDate),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Next Due Date (Optional)
              InkWell(
                onTap: () => _selectDate(context, true),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Prossima Scadenza (Richiamo)',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.event_repeat),
                    suffixIcon: _nextDueDate != null 
                        ? IconButton(
                            icon: const Icon(Icons.clear), 
                            onPressed: () => setState(() => _nextDueDate = null),
                          )
                        : null,
                  ),
                  child: Text(
                    _nextDueDate != null 
                        ? DateFormat('dd/MM/yyyy').format(_nextDueDate!)
                        : 'Nessuna scadenza',
                    style: TextStyle(
                       color: _nextDueDate != null ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Veterinarian
              TextFormField(
                controller: _vetController,
                decoration: const InputDecoration(
                  labelText: 'Veterinario / Clinica',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Note aggiuntive',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Salva nel Libretto'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
