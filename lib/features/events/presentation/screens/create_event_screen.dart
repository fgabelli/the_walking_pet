import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/services/event_service.dart';
import '../../../../shared/models/event_model.dart';
import '../../../../core/services/location_service.dart'; // For initial location
import '../../../../features/map/presentation/providers/map_provider.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationNameController = TextEditingController();
  
  EventType _selectedType = EventType.walk;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1)); // Default tomorrow
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crea Nuovo Evento'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titolo Evento',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Inserisci un titolo' : null,
              ),
              const SizedBox(height: 16),
              
              // Description
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descrizione',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Inserisci una descrizione' : null,
              ),
              const SizedBox(height: 16),
              
              // Type
              DropdownButtonFormField<EventType>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Tipo di Evento',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: EventType.values.map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type.displayName),
                )).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedType = val);
                },
              ),
              const SizedBox(height: 16),
              
              // Date & Time
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Data',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickTime(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Ora',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        child: Text(_selectedTime.format(context)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Location Name
              TextFormField(
                controller: _locationNameController,
                decoration: const InputDecoration(
                  labelText: 'Luogo / Indirizzo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                  helperText: 'Per ora la posizione GPS sarà la tua attuale'
                ),
                validator: (val) => val == null || val.isEmpty ? 'Inserisci il luogo' : null,
              ),
              const SizedBox(height: 32),
              
              // Submit
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Pubblica Evento'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        final currentUser = ref.read(authServiceProvider).currentUser;
        if (currentUser == null) throw Exception('Utente non autenticato');

        // Use current location for now (Simplification)
        // Ideally we would have a Location Picker on map
        final position = await ref.read(locationServiceProvider).getCurrentPosition();
        if (position == null) throw Exception('Impossibile ottenere la posizione');

        final eventDateTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );

        final newEvent = EventModel(
          id: '',
          title: _titleController.text,
          description: _descController.text,
          creatorId: currentUser.uid,
          date: eventDateTime,
          latitude: position.latitude,
          longitude: position.longitude,
          locationName: _locationNameController.text,
          attendees: [currentUser.uid], // Creator is first attendee
          type: _selectedType,
          createdAt: DateTime.now(),
        );

        await ref.read(eventServiceProvider).createEvent(newEvent);
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Evento creato con successo!')),
          );
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
}
