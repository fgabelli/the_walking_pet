import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/health_service.dart';
import '../../../../shared/models/health_record_model.dart';
import '../../../../shared/models/dog_model.dart';
import '../../../../shared/data/vaccination_protocols.dart';
import '../../../../core/theme/app_colors.dart';

class AddHealthRecordScreen extends ConsumerStatefulWidget {
  final String petId;
  final DogModel? pet;
  final HealthRecordType initialType;
  const AddHealthRecordScreen({super.key, required this.petId, this.pet, this.initialType = HealthRecordType.vaccine});

  @override
  ConsumerState<AddHealthRecordScreen> createState() => _AddHealthRecordScreenState();
}

class _AddHealthRecordScreenState extends ConsumerState<AddHealthRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late HealthRecordType _selectedType;
  final _titleController = TextEditingController();
  final _vetController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  DateTime? _nextDueDate;
  bool _isLoading = false;

  VaccinationProtocol? _selectedProtocol;
  bool _isCustomVaccine = false;
  bool _nextDueDateManuallySet = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _vetController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  List<VaccinationProtocol> get _availableVaccines {
    if (widget.pet == null) return [];
    return VaccinationProtocols.forSpecies(widget.pet!.species);
  }

  void _onProtocolSelected(VaccinationProtocol? protocol) {
    setState(() {
      _selectedProtocol = protocol;
      _isCustomVaccine = false;
      if (protocol != null) {
        _titleController.text = protocol.name;
        _autoCalculateNextDueDate();
      }
    });
  }

  void _onCustomVaccineSelected() {
    setState(() {
      _selectedProtocol = null;
      _isCustomVaccine = true;
      _titleController.clear();
      _nextDueDate = null;
      _nextDueDateManuallySet = false;
    });
  }

  void _autoCalculateNextDueDate() {
    if (_selectedProtocol != null && !_nextDueDateManuallySet) {
      setState(() {
        _nextDueDate = _selectedDate.add(Duration(days: _selectedProtocol!.boosterIntervalDays));
      });
    }
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
          _nextDueDateManuallySet = true;
        } else {
          _selectedDate = picked;
          _autoCalculateNextDueDate();
        }
      });
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        final vaccineTitle = _selectedType == HealthRecordType.vaccine
            ? (_selectedProtocol?.name ?? _titleController.text)
            : _titleController.text;

        final newRecord = HealthRecordModel(
          id: '', // Firestore generates this
          petId: widget.petId,
          type: _selectedType,
          title: vaccineTitle,
          specificName: _selectedType == HealthRecordType.vaccine ? vaccineTitle : null,
          date: _selectedDate,
          nextDueDate: _nextDueDate,
          reminderEnabled: _nextDueDate != null,
          isCompleted: _selectedDate.isBefore(DateTime.now()) || _selectedDate.isAtSameMomentAs(DateTime.now()),
          veterinarianName: _vetController.text,
          notes: _notesController.text,
        );

        await ref.read(healthServiceProvider).addHealthRecord(
          newRecord,
          petName: widget.pet?.name,
        );
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
    final isVaccine = _selectedType == HealthRecordType.vaccine;
    final hasProtocols = widget.pet != null && isVaccine;

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
                initialValue: _selectedType,
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
                  if (val != null) {
                    setState(() {
                      _selectedType = val;
                      _selectedProtocol = null;
                      _isCustomVaccine = false;
                      _nextDueDateManuallySet = false;
                      if (val != HealthRecordType.vaccine) {
                        _nextDueDate = null;
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Vaccine Protocol Selector (only for vaccine type with pet data)
              if (hasProtocols) ...[
                _buildVaccineSelector(),
                const SizedBox(height: 16),
              ],

              // Title (shown always for non-vaccine, or for custom vaccine, or when no pet data)
              if (!hasProtocols || _isCustomVaccine || !isVaccine)
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: _isCustomVaccine ? 'Nome vaccino personalizzato' : 'Titolo (es. Vaccino Rabbia)',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.title),
                  ),
                  validator: (value) {
                    if (!hasProtocols || _isCustomVaccine || !isVaccine) {
                      return value == null || value.isEmpty ? 'Inserisci un titolo' : null;
                    }
                    return null;
                  },
                ),
              if (!hasProtocols || _isCustomVaccine || !isVaccine)
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
                            onPressed: () => setState(() {
                              _nextDueDate = null;
                              _nextDueDateManuallySet = false;
                            }),
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
              if (_nextDueDate != null && _selectedProtocol != null && !_nextDueDateManuallySet)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 12),
                  child: Text(
                    'Calcolata automaticamente (${_selectedProtocol!.boosterIntervalDays} giorni)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
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

  Widget _buildVaccineSelector() {
    final vaccines = _availableVaccines;
    final isSelected = _selectedProtocol != null || _isCustomVaccine;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Seleziona vaccino',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        ...vaccines.map((protocol) {
          final selected = _selectedProtocol?.name == protocol.name;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => _onProtocolSelected(protocol),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? AppColors.primary : Colors.grey.shade300,
                    width: selected ? 2 : 1,
                  ),
                  color: selected ? AppColors.primary.withOpacity(0.05) : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      color: selected ? AppColors.primary : Colors.grey,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  protocol.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: selected ? AppColors.primary : null,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: protocol.isCore
                                      ? Colors.teal.withOpacity(0.1)
                                      : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  protocol.isCore ? 'Obbligatorio' : 'Consigliato',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: protocol.isCore ? Colors.teal : Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            protocol.description,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        // Custom option
        InkWell(
          onTap: _onCustomVaccineSelected,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isCustomVaccine ? AppColors.primary : Colors.grey.shade300,
                width: _isCustomVaccine ? 2 : 1,
              ),
              color: _isCustomVaccine ? AppColors.primary.withOpacity(0.05) : null,
            ),
            child: Row(
              children: [
                Icon(
                  _isCustomVaccine ? Icons.check_circle : Icons.circle_outlined,
                  color: _isCustomVaccine ? AppColors.primary : Colors.grey,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  'Altro (personalizzato)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isCustomVaccine ? AppColors.primary : null,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isSelected)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Seleziona un vaccino',
              style: TextStyle(fontSize: 12, color: Colors.red.shade400),
            ),
          ),
      ],
    );
  }
}
