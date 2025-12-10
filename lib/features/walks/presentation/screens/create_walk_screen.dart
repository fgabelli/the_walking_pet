import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
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
      // Combine date and time
      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // Check if coordinates are 0.0 OR are the default Rome coordinates (which means they might be wrong for a non-Rome address)
      bool needsGeocoding = (_latitude == 0.0 && _longitude == 0.0);
      
      // If we have Rome coordinates but the address doesn't seem to contain "Roma", try to re-geocode to fix old data
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
                return; // Stop saving to prevent bad data
             }
           }
        } catch (_) {
           if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Impossibile geolocalizzare questo indirizzo. Selezionalo dal menu a tendina.')),
              );
              return; // Stop saving
           }
        }
      }

      // Default to Rome ONLY if explicit fallback is needed and we really have no data
      // But since we return above on failure, this might be redundant or for empty address cases (which are blocked by validator)
      if (!_isEditing && (_latitude == 0.0 && _longitude == 0.0)) {
         // Final fallback if something really weird happens
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
        );

        await ref.read(walkControllerProvider.notifier).updateWalk(updatedWalk);
        
        if (mounted) {
          final state = ref.read(walkControllerProvider);
          if (state.error == null) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Passeggiata aggiornata!')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error!)),
            );
          }
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
            );

        if (mounted) {
          final state = ref.read(walkControllerProvider);
          if (state.error == null) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Passeggiata creata!')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error!)),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final walkState = ref.watch(walkControllerProvider);
    final dateFormat = DateFormat('EEE d MMM yyyy', 'it');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifica Passeggiata' : 'Organizza Passeggiata'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titolo',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Inserisci un titolo' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descrizione',
                  prefixIcon: Icon(Icons.description),
                  alignLabelWithHint: true,
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Inserisci una descrizione' : null,
              ),
              const SizedBox(height: 24),
              
              // Date & Time
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Data',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(dateFormat.format(_selectedDate)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Ora',
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        child: Text(_selectedTime.format(context)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Duration
              DropdownButtonFormField<int>(
                value: _duration,
                decoration: const InputDecoration(
                  labelText: 'Durata (minuti)',
                  prefixIcon: Icon(Icons.timer),
                ),
                items: [30, 45, 60, 90, 120].map((e) {
                  return DropdownMenuItem(
                    value: e,
                    child: Text('$e min'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _duration = value);
                },
              ),
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
                    // Address is already updated in controller by the widget
                  });
                },
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Inserisci un luogo' : null,
              ),
              const SizedBox(height: 32),

              // Submit
              ElevatedButton(
                onPressed: walkState.isLoading ? null : _handleCreateWalk,
                child: walkState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isEditing ? 'Aggiorna Passeggiata' : 'Crea Passeggiata'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
