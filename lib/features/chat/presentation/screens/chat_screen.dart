import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/chat_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/models/dog_model.dart';
import '../providers/chat_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/dog_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final UserModel? otherUser;

  const ChatScreen({
    super.key,
    required this.chatId,
    this.otherUser,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _editController = TextEditingController();

  // Reply state
  MessageModel? _replyingTo;
  // Edit state
  MessageModel? _editingMessage;

  @override
  void dispose() {
    _messageController.dispose();
    _editController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    if (_editingMessage != null) {
      // Editing existing message
      ref.read(chatControllerProvider.notifier).editMessage(
            widget.chatId,
            _editingMessage!.id,
            _messageController.text,
          );
      setState(() => _editingMessage = null);
    } else {
      // Sending new message (with optional reply)
      ref.read(chatControllerProvider.notifier).sendMessage(
            widget.chatId,
            _messageController.text,
            replyTo: _replyingTo,
          );
      setState(() => _replyingTo = null);
    }

    _messageController.clear();
  }

  void _startReply(MessageModel message) {
    setState(() {
      _replyingTo = message;
      _editingMessage = null;
    });
    // Focus the text field
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _startEdit(MessageModel message) {
    setState(() {
      _editingMessage = message;
      _replyingTo = null;
    });
    _messageController.text = message.text;
  }

  void _cancelReplyOrEdit() {
    setState(() {
      _replyingTo = null;
      _editingMessage = null;
    });
    _messageController.clear();
  }

  // ─── Attachment Options ───
  void _showAttachmentOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Condividi',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                child: const Icon(Icons.photo_library, color: Colors.blue),
              ),
              title: const Text('Foto dalla Galleria'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSendImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.shade50,
                child: const Icon(Icons.camera_alt, color: Colors.green),
              ),
              title: const Text('Scatta Foto'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSendImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.red.shade50,
                child: const Icon(Icons.location_on, color: Colors.red),
              ),
              title: const Text('La Tua Posizione'),
              onTap: () {
                Navigator.pop(ctx);
                _sendCurrentLocation();
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange.shade50,
                child: const Icon(Icons.pets, color: Colors.orange),
              ),
              title: const Text('Profilo del tuo Pet'),
              onTap: () {
                Navigator.pop(ctx);
                _showPetPicker();
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.purple.shade50,
                child: const Icon(Icons.directions_walk, color: Colors.purple),
              ),
              title: const Text('Proponi Passeggiata'),
              onTap: () {
                Navigator.pop(ctx);
                _showWalkInviteForm();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      final file = File(pickedFile.path);
      await ref.read(chatControllerProvider.notifier).sendImage(widget.chatId, file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore invio foto: $e')),
        );
      }
    }
  }

  Future<void> _sendCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      String? address;
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          address = [p.street, p.locality].where((s) => s != null && s.isNotEmpty).join(', ');
        }
      } catch (_) {}

      await ref.read(chatControllerProvider.notifier).sendLocation(
        widget.chatId,
        position.latitude,
        position.longitude,
        address,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore posizione: $e')),
        );
      }
    }
  }

  void _showPetPicker() {
    final currentUser = ref.read(authServiceProvider).currentUser;
    if (currentUser == null) return;

    final dogService = ref.read(dogServiceProvider);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Scegli un Pet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Divider(height: 1),
            SizedBox(
              height: 250,
              child: StreamBuilder<List<DogModel>>(
                stream: dogService.getDogsStreamByOwnerId(currentUser.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final dogs = snapshot.data ?? [];
                  if (dogs.isEmpty) {
                    return const Center(
                      child: Text('Non hai ancora aggiunto pet.', style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return ListView.builder(
                    itemCount: dogs.length,
                    itemBuilder: (context, index) {
                      final dog = dogs[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: dog.photoUrl != null ? NetworkImage(dog.photoUrl!) : null,
                          child: dog.photoUrl == null ? const Icon(Icons.pets) : null,
                        ),
                        title: Text(dog.name),
                        subtitle: Text('${dog.breed} • ${dog.age} anni'),
                        onTap: () {
                          Navigator.pop(ctx);
                          ref.read(chatControllerProvider.notifier).sendPetCard(widget.chatId, dog);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWalkInviteForm() {
    final locationController = TextEditingController();
    final noteController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(hours: 1));
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Proponi una Passeggiata 🚶',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: locationController,
                decoration: InputDecoration(
                  labelText: 'Dove?',
                  hintText: 'Es. Parco Sempione',
                  prefixIcon: const Icon(Icons.location_on),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (picked != null) {
                          setSheetState(() => selectedDate = DateTime(
                            picked.year, picked.month, picked.day,
                            selectedTime.hour, selectedTime.minute,
                          ));
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Data',
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setSheetState(() {
                            selectedTime = picked;
                            selectedDate = DateTime(
                              selectedDate.year, selectedDate.month, selectedDate.day,
                              picked.hour, picked.minute,
                            );
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Ora',
                          prefixIcon: const Icon(Icons.access_time),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(selectedTime.format(ctx)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  labelText: 'Nota (opzionale)',
                  hintText: 'Es. Ci vediamo all\'ingresso!',
                  prefixIcon: const Icon(Icons.note),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  if (locationController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Inserisci un luogo')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  ref.read(chatControllerProvider.notifier).sendWalkInvite(
                    widget.chatId,
                    locationName: locationController.text.trim(),
                    latitude: 0, // Simplified: no geocoding for invite
                    longitude: 0,
                    dateTime: selectedDate,
                    note: noteController.text.trim().isNotEmpty ? noteController.text.trim() : null,
                  );
                },
                icon: const Icon(Icons.send),
                label: const Text('Invia Proposta'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Report / Block / Delete Actions ───

  void _showChatActions(BuildContext context) {
    final otherUser = widget.otherUser;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                otherUser?.fullName ?? 'Utente',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.orange),
              title: const Text('Segnala utente'),
              subtitle: const Text('Invia una segnalazione al team'),
              onTap: () {
                Navigator.pop(ctx);
                _showReportDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('Blocca utente'),
              subtitle: const Text('Non potrà più contattarti'),
              onTap: () {
                Navigator.pop(ctx);
                _showBlockConfirmation(context);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Elimina conversazione', style: TextStyle(color: Colors.red)),
              subtitle: const Text('Elimina tutti i messaggi'),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteConfirmation(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    String? selectedReason;
    final descriptionController = TextEditingController();
    final reasons = [
      'Comportamento inappropriato',
      'Molestie o bullismo',
      'Spam o pubblicità',
      'Contenuti offensivi',
      'Profilo falso',
      'Altro',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.flag_outlined, color: Colors.orange),
              SizedBox(width: 8),
              Text('Segnala utente'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Motivo della segnalazione:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                ...reasons.map((reason) => RadioListTile<String>(
                  title: Text(reason, style: const TextStyle(fontSize: 14)),
                  value: reason,
                  groupValue: selectedReason,
                  onChanged: (val) => setDialogState(() => selectedReason = val),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  activeColor: AppColors.primary,
                )),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Descrizione (opzionale)...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: selectedReason == null
                  ? null
                  : () async {
                      if (widget.otherUser == null) return;
                      Navigator.pop(ctx);
                      await ref.read(chatControllerProvider.notifier).reportUserFromChat(
                        otherUserId: widget.otherUser!.uid,
                        reason: selectedReason!,
                        description: descriptionController.text.trim().isNotEmpty
                            ? descriptionController.text.trim()
                            : null,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Segnalazione inviata. Grazie per aver segnalato.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Segnala'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockConfirmation(BuildContext context) {
    final otherName = widget.otherUser?.fullName ?? 'questo utente';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.red),
            SizedBox(width: 8),
            Expanded(child: Text('Blocca utente')),
          ],
        ),
        content: Text(
          'Sei sicuro di voler bloccare $otherName?\n\n'
          '• Non potrà più inviarti messaggi\n'
          '• Verrà rimosso dai tuoi amici\n'
          '• Non vedrà il tuo profilo',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (widget.otherUser == null) return;
              await ref.read(chatControllerProvider.notifier)
                  .blockUserFromChat(widget.otherUser!.uid);
              await ref.read(chatControllerProvider.notifier)
                  .deleteChat(widget.chatId);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$otherName è stato bloccato.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Blocca'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Expanded(child: Text('Elimina conversazione')),
          ],
        ),
        content: const Text(
          'Sei sicuro di voler eliminare questa conversazione?\n\n'
          'Tutti i messaggi verranno eliminati in modo permanente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(chatControllerProvider.notifier)
                  .deleteChat(widget.chatId);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Conversazione eliminata.'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  // ─── Message long-press actions ───
  void _showMessageActions(BuildContext context, MessageModel message, bool isMe) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Quick reactions row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['❤️', '😂', '👍', '😮', '😢', '🙏'].map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      ref.read(chatControllerProvider.notifier)
                          .toggleReaction(widget.chatId, message.id, emoji);
                    },
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(emoji, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1),
            // Reply
            ListTile(
              leading: const Icon(Icons.reply, color: AppColors.primary),
              title: const Text('Rispondi'),
              onTap: () {
                Navigator.pop(ctx);
                _startReply(message);
              },
            ),
            // Copy
            ListTile(
              leading: Icon(Icons.copy, color: Colors.grey[700]),
              title: const Text('Copia testo'),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: message.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Testo copiato'), duration: Duration(seconds: 1)),
                );
              },
            ),
            // Edit (only own messages)
            if (isMe)
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.orange),
                title: const Text('Modifica'),
                onTap: () {
                  Navigator.pop(ctx);
                  _startEdit(message);
                },
              ),
            // Delete (only own messages)
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Elimina messaggio', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteMessage(context, message);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteMessage(BuildContext context, MessageModel message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Elimina messaggio'),
        content: const Text('Vuoi eliminare questo messaggio? Tutti vedranno che è stato eliminato.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(chatControllerProvider.notifier)
                  .deleteMessage(widget.chatId, message.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatAsync = ref.watch(chatStreamProvider(widget.chatId));
    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));
    final currentUser = ref.watch(authServiceProvider).currentUser;

    messagesAsync.whenData((messages) {
      if (messages.isNotEmpty && currentUser != null) {
        final hasUnread = messages.any((msg) => msg.senderId != currentUser.uid && !msg.isRead);
        if (hasUnread) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(chatServiceProvider).markMessagesAsRead(widget.chatId, currentUser.uid);
          });
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUser?.fullName ?? 'Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Opzioni',
            onPressed: () => _showChatActions(context),
          ),
        ],
      ),
      body: chatAsync.when(
        data: (chat) {
          final isPending = chat.status == ChatStatus.pending;
          final isInitiator = chat.initiatorId == currentUser?.uid;
          final isAccepted = chat.status == ChatStatus.accepted;

          return Column(
            children: [
              // Permission Banner
              if (isPending)
                Container(
                  padding: const EdgeInsets.all(12),
                  color: isInitiator ? Colors.orange.shade100 : Colors.blue.shade100,
                  child: Row(
                    children: [
                      Icon(
                        isInitiator ? Icons.access_time : Icons.info_outline,
                        color: isInitiator ? Colors.orange.shade800 : Colors.blue.shade800,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isInitiator
                              ? 'In attesa che l\'utente accetti la richiesta.'
                              : 'Questa persona vuole inviarti un messaggio.',
                          style: TextStyle(
                            color: isInitiator ? Colors.orange.shade900 : Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Accept/Decline Buttons for Recipient
              if (isPending && !isInitiator)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            ref.read(chatControllerProvider.notifier).declineChat(widget.chatId);
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                          child: const Text('Rifiuta'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            ref.read(chatControllerProvider.notifier).acceptChat(widget.chatId);
                          },
                          child: const Text('Accetta'),
                        ),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: messagesAsync.when(
                  data: (messages) {
                    if (messages.isEmpty) {
                      return const Center(child: Text('Nessun messaggio'));
                    }

                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderId == currentUser?.uid;
                        
                        return _MessageBubble(
                          message: message,
                          isMe: isMe,
                          otherUserName: widget.otherUser?.fullName ?? 'Utente',
                          onLongPress: () => _showMessageActions(context, message, isMe),
                          onSwipeReply: () => _startReply(message),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('Errore: $e')),
                ),
              ),
              
              // Input Area (Only if accepted)
              if (isAccepted)
                _buildInputArea()
              else if (isPending && isInitiator)
                 _buildInputArea(),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Errore: $e')),
      ),
    );
  }

  Widget _buildInputArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reply / Edit preview bar
        if (_replyingTo != null || _editingMessage != null)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _editingMessage != null ? Colors.orange : AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _editingMessage != null
                            ? 'Modifica messaggio'
                            : 'Rispondi',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _editingMessage != null ? Colors.orange : AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _editingMessage?.text ?? _replyingTo?.text ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: _cancelReplyOrEdit,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),

        // Text input
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                offset: const Offset(0, -1),
                blurRadius: 5,
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showAttachmentOptions(context),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: _editingMessage != null
                          ? 'Modifica messaggio...'
                          : 'Scrivi un messaggio...',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _editingMessage != null ? Icons.check : Icons.send,
                    color: AppColors.primary,
                  ),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Message Bubble Widget ─────────────────────────────

class _MessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;
  final String otherUserName;
  final VoidCallback onLongPress;
  final VoidCallback onSwipeReply;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.otherUserName,
    required this.onLongPress,
    required this.onSwipeReply,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _showTimestamp = false;

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return DateFormat('HH:mm').format(dt);
    } else if (diff.inDays == 1) {
      return 'Ieri ${DateFormat('HH:mm').format(dt)}';
    } else if (diff.inDays < 7) {
      return DateFormat('EEE HH:mm', 'it_IT').format(dt);
    } else {
      return DateFormat('dd/MM/yy HH:mm').format(dt);
    }
  }

  Widget _buildMessageContent(BuildContext context, MessageModel message, bool isMe) {
    switch (message.type) {
      case MessageType.image:
        final imageUrl = message.metadata['imageUrl'] as String?;
        if (imageUrl == null) {
          return Text(message.text, style: TextStyle(color: isMe ? Colors.white : Colors.black87));
        }
        return GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
            settings: const RouteSettings(name: 'scaffold'),
              builder: (_) => Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
                body: Center(child: InteractiveViewer(child: Image.network(imageUrl))),
              ),
            ));
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 250),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SizedBox(height: 100, width: 100, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                },
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40),
              ),
            ),
          ),
        );

      case MessageType.location:
        final lat = message.metadata['latitude'];
        final lng = message.metadata['longitude'];
        final address = message.metadata['address'] as String?;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.location_on, size: 16, color: isMe ? Colors.white70 : Colors.red),
              const SizedBox(width: 4),
              Flexible(child: Text(address ?? 'Posizione condivisa', style: TextStyle(fontWeight: FontWeight.w600, color: isMe ? Colors.white : Colors.black87))),
            ]),
            if (lat != null && lng != null) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => launchUrl(Uri.parse('https://maps.apple.com/?q=$lat,$lng'), mode: LaunchMode.externalApplication),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: isMe ? Colors.white.withOpacity(0.2) : AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.map, size: 14, color: isMe ? Colors.white : AppColors.primary),
                    const SizedBox(width: 4),
                    Text('Apri in Mappe', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isMe ? Colors.white : AppColors.primary)),
                  ]),
                ),
              ),
            ],
          ],
        );

      case MessageType.petCard:
        final petName = message.metadata['petName'] as String? ?? 'Pet';
        final petBreed = message.metadata['petBreed'] as String? ?? '';
        final petAge = message.metadata['petAge'];
        final petGender = message.metadata['petGender'] as String?;
        final petPhotoUrl = message.metadata['petPhotoUrl'] as String?;
        return Row(mainAxisSize: MainAxisSize.min, children: [
          if (petPhotoUrl != null)
            ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(petPhotoUrl, width: 40, height: 40, fit: BoxFit.cover))
          else
            CircleAvatar(radius: 20, backgroundColor: isMe ? Colors.white24 : Colors.orange.shade50, child: Icon(Icons.pets, size: 18, color: isMe ? Colors.white : Colors.orange)),
          const SizedBox(width: 10),
          Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(petName, style: TextStyle(fontWeight: FontWeight.w700, color: isMe ? Colors.white : Colors.black87, fontSize: 15)),
            Text([petBreed, if (petAge != null) '$petAge anni', if (petGender != null) petGender == 'male' ? '♂' : '♀'].where((s) => s.isNotEmpty).join(' • '), style: TextStyle(fontSize: 12, color: isMe ? Colors.white70 : Colors.grey[600])),
          ])),
        ]);

      case MessageType.walkInvite:
        final locationName = message.metadata['locationName'] as String? ?? '';
        final dateTimeStr = message.metadata['dateTime'] as String?;
        final note = message.metadata['note'] as String?;
        DateTime? walkDateTime;
        if (dateTimeStr != null) { try { walkDateTime = DateTime.parse(dateTimeStr); } catch (_) {} }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: isMe ? Colors.white.withOpacity(0.2) : Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.directions_walk, size: 14, color: isMe ? Colors.white : Colors.purple),
              const SizedBox(width: 4),
              Text('Proposta Passeggiata', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isMe ? Colors.white : Colors.purple)),
            ]),
          ),
          const SizedBox(height: 8),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.location_on, size: 14, color: isMe ? Colors.white70 : Colors.grey[600]),
            const SizedBox(width: 4),
            Flexible(child: Text(locationName, style: TextStyle(fontWeight: FontWeight.w600, color: isMe ? Colors.white : Colors.black87))),
          ]),
          if (walkDateTime != null) ...[
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.calendar_today, size: 14, color: isMe ? Colors.white70 : Colors.grey[600]),
              const SizedBox(width: 4),
              Text(DateFormat('EEE dd MMM, HH:mm', 'it_IT').format(walkDateTime), style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
            ]),
          ],
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('💬 $note', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: isMe ? Colors.white70 : Colors.grey[600])),
          ],
        ]);

      case MessageType.text:
      default:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(message.text, style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
          if (message.isEdited)
            Padding(padding: const EdgeInsets.only(top: 2), child: Text('modificato', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: isMe ? Colors.white60 : Colors.grey[500]))),
        ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isMe = widget.isMe;

    // Deleted message
    if (message.isDeleted) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 6),
              Text(
                'Messaggio eliminato',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Reactions display
    final reactions = message.reactions;
    final hasReactions = reactions.isNotEmpty;

    // Group reactions by emoji for count
    final reactionCounts = <String, int>{};
    for (final emoji in reactions.values) {
      reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
    }

    return Dismissible(
      key: ValueKey('swipe_${message.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        widget.onSwipeReply();
        return false; // Don't actually dismiss
      },
      background: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Icon(Icons.reply, color: Colors.grey[400]),
        ),
      ),
      child: GestureDetector(
        onTap: () {
          setState(() => _showTimestamp = !_showTimestamp);
        },
        onLongPress: widget.onLongPress,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Reply preview (if this message is a reply)
            if (message.replyToText != null)
              Container(
                margin: EdgeInsets.only(
                  top: 4,
                  left: isMe ? 60 : 0,
                  right: isMe ? 0 : 60,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isMe
                      ? AppColors.primary.withOpacity(0.15)
                      : Colors.grey[200]?.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border(
                    left: BorderSide(
                      color: isMe ? AppColors.primary : Colors.grey[400]!,
                      width: 3,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.replyToSenderId == (isMe ? message.senderId : null)
                          ? 'Tu'
                          : widget.otherUserName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isMe ? AppColors.primary : Colors.grey[600],
                      ),
                    ),
                    Text(
                      message.replyToText!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

            // Main bubble
            Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    margin: EdgeInsets.only(
                      top: message.replyToText != null ? 2 : 4,
                      bottom: hasReactions ? 12 : 4,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? AppColors.primary : Colors.grey[200],
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                        bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                      ),
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: _buildMessageContent(context, message, isMe),
                  ),

                  // Reactions badge
                  if (hasReactions)
                    Positioned(
                      bottom: 0,
                      right: isMe ? 8 : null,
                      left: isMe ? null : 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: reactionCounts.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 1),
                              child: Text(
                                entry.value > 1 ? '${entry.key}${entry.value}' : entry.key,
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Timestamp (shown on tap)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: _showTimestamp
                  ? Padding(
                      padding: EdgeInsets.only(
                        left: isMe ? 0 : 4,
                        right: isMe ? 4 : 0,
                        bottom: 4,
                      ),
                      child: Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[400],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
