import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/models/walk_model.dart';
import '../providers/walk_provider.dart';
import '../../../../shared/widgets/address_autocomplete_field.dart';
import 'package:geocoding/geocoding.dart';

class CreateWalkScreen extends ConsumerStatefulWidget {
  final WalkModel? walkToEdit;

  const CreateWalkScreen({super.key, this.walkToEdit});

  @override
  ConsumerState<CreateWalkScreen> createState() => _CreateWalkScreenState();
}

class _CreateWalkScreenState extends ConsumerState<CreateWalkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _duration = 30;
  
  // Placeholder for location selection
  // In a real app, we would use a map picker or places autocomplete
  // For now, we'll just take text input for address and mock coordinates
  double _latitude = 0.0;
  double _longitude = 0.0;
  bool _isEditing = false;
  Recurrence _recurrence = Recurrence.none;
  List<int> _recurrenceDays = []; // Added

  @override
  void initState() {
    super.initState();
    if (widget.walkToEdit != null) {
      _isEditing = true;
      final walk = widget.walkToEdit!;
      _titleController.text = walk.title;
      _descriptionController.text = walk.description;
      _addressController.text = walk.meetingPoint.address;
      _selectedDate = walk.date;
      _selectedTime = TimeOfDay.fromDateTime(walk.date);
      _duration = walk.duration;
      _latitude = walk.meetingPoint.latitude;
      _longitude = walk.meetingPoint.longitude;
      _recurrence = walk.recurrence;
      _recurrenceDays = List.from(walk.recurrenceDays); // Added
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _handleCreateWalk() async {
    if (_formKey.currentState!.validate()) {
      // Validate Custom Recurrence
      if (_recurrence == Recurrence.custom && _recurrenceDays.isEmpty) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Seleziona almeno un giorno per la ripetizione personalizzata.')),
           );
           return;
        }
      }

      // Combine date and time
      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // Check if coordinates are 0.0 OR are the default Rome coordinates
      bool needsGeocoding = (_latitude == 0.0 && _longitude == 0.0);
      
      // If we have Rome coordinates but the address doesn't seem to contain "Roma"
      if ((_latitude - 41.9028).abs() < 0.0001 && (_longitude - 12.4964).abs() < 0.0001) {
         if (!_addressController.text.toLowerCase().contains('roma')) {
           needsGeocoding = true;
         }
      }

      if (needsGeocoding && _addressController.text.isNotEmpty) {
        try {
           final locations = await locationFromAddress(_addressController.text);
           if (locations.isNotEmpty) {
             _latitude = locations.first.latitude;
             _longitude = locations.first.longitude;
           } else {
             if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Indirizzo non trovato, usare la ricerca automatica.')),
                );
                return;
             }
           }
        } catch (_) {
           if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Impossibile geolocalizzare questo indirizzo. Selezionalo dal menu a tendina.')),
              );
              return;
           }
        }
      }

      // Default to Rome ONLY if explicit fallback is needed and we really have no data
      if (!_isEditing && (_latitude == 0.0 && _longitude == 0.0)) {
        _latitude = 41.9028;
        _longitude = 12.4964;
      }

      if (_isEditing) {
        final updatedWalk = widget.walkToEdit!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          date: dateTime,
          duration: _duration,
          meetingPoint: MeetingPoint(
            latitude: _latitude,
            longitude: _longitude,
            address: _addressController.text.trim(),
          ),
          recurrence: _recurrence,
          recurrenceDays: _recurrenceDays, // Added
        );

        await ref.read(walkControllerProvider.notifier).updateWalk(updatedWalk);
        
        if (mounted) {
           // ... handle success ...
           Navigator.pop(context);
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passeggiata aggiornata!')));
        }
      } else {
        await ref.read(walkControllerProvider.notifier).createWalk(
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim(),
              date: dateTime,
              duration: _duration,
              meetingPoint: MeetingPoint(
                latitude: _latitude,
                longitude: _longitude,
                address: _addressController.text.trim(),
              ),
              recurrence: _recurrence,
              recurrenceDays: _recurrenceDays, // Added
            );

        if (mounted) {
           // ... handle success ...
           Navigator.pop(context);
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passeggiata creata!')));
        }
      }
    }
  }

  // Helper widget for Day Selector
  Widget _buildDaySelector() {
     final days = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
     return Wrap(
       spacing: 8,
       children: List.generate(7, (index) {
          final dayNum = index + 1; // 1 = Mon
          final isSelected = _recurrenceDays.contains(dayNum);
          return FilterChip(
            label: Text(days[index]),
            selected: isSelected,
            onSelected: (selected) {
               setState(() {
                 if (selected) {
                   _recurrenceDays.add(dayNum);
                   _recurrenceDays.sort();
                 } else {
                   _recurrenceDays.remove(dayNum);
                 }
               });
            },
          );
       }),
     );
  }

  @override
  Widget build(BuildContext context) {
    // ... setup ...
    final walkState = ref.watch(walkControllerProvider);
    final dateFormat = DateFormat('EEE d MMM yyyy', 'it');

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Modifica Passeggiata' : 'Organizza Passeggiata')),
      body: SingleChildScrollView(
         padding: const EdgeInsets.all(24),
         child: Form(
           key: _formKey,
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.stretch,
             children: [
               // ... existing fields ...
               TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Titolo', prefixIcon: Icon(Icons.title)),
                validator: (value) => value?.isEmpty ?? true ? 'Inserisci un titolo' : null,
               ),
               const SizedBox(height: 16),
               TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Descrizione', prefixIcon: Icon(Icons.description)),
                validator: (value) => value?.isEmpty ?? true ? 'Inserisci una descrizione' : null,
               ),
               const SizedBox(height: 24),
               
               // Date and Time Row
               Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Data', prefixIcon: Icon(Icons.calendar_today)),
                        child: Text(dateFormat.format(_selectedDate)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Ora', prefixIcon: Icon(Icons.access_time)),
                        child: Text(_selectedTime.format(context)),
                      ),
                    ),
                  ),
                ],
               ),
               const SizedBox(height: 16),

              // Duration
              DropdownButtonFormField<int>(
                initialValue: _duration,
                decoration: const InputDecoration(labelText: 'Durata (minuti)', prefixIcon: Icon(Icons.timer)),
                items: [30, 45, 60, 90, 120].map((e) => DropdownMenuItem(value: e, child: Text('$e min'))).toList(),
                onChanged: (value) { if (value != null) setState(() => _duration = value); },
              ),
              const SizedBox(height: 16),
              
              // Recurrence
              DropdownButtonFormField<Recurrence>(
                initialValue: _recurrence,
                decoration: const InputDecoration(labelText: 'Ripetizione', prefixIcon: Icon(Icons.update)),
                items: Recurrence.values.map((e) => DropdownMenuItem(value: e, child: Text(e.displayName))).toList(),
                onChanged: (value) { if (value != null) setState(() => _recurrence = value); },
              ),
              
              // Custom Day Selector (Added)
              if (_recurrence == Recurrence.custom) ...[
                 const SizedBox(height: 8),
                 Text('Giorni:', style: Theme.of(context).textTheme.bodySmall),
                 _buildDaySelector(),
              ],
              
              const SizedBox(height: 16),

              // Location
              AddressAutocompleteField(
                controller: _addressController,
                label: 'Punto di ritrovo',
                initialValue: _addressController.text,
                onSelected: (place) {
                  setState(() {
                    _latitude = place.latitude;
                    _longitude = place.longitude;
                  });
                },
                validator: (value) => value?.isEmpty ?? true ? 'Inserisci un luogo' : null,
              ),
              const SizedBox(height: 32),

              // Submit Button
              ElevatedButton(
                onPressed: walkState.isLoading ? null : _handleCreateWalk,
                child: walkState.isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_isEditing ? 'Aggiorna Passeggiata' : 'Crea Passeggiata'),
              ),
             ],
           ),
         ),
      ),
    );
  }
} // End Class
