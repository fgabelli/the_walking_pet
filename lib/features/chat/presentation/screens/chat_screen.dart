import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/chat_model.dart';
import '../providers/chat_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String? otherUserName; // Optional, for header

  const ChatScreen({
    super.key,
    required this.chatId,
    this.otherUserName,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    
    ref.read(chatControllerProvider.notifier).sendMessage(
      widget.chatId,
      _messageController.text,
    );
    
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final chatAsync = ref.watch(chatStreamProvider(widget.chatId));
    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));
    final currentUser = ref.watch(authServiceProvider).currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserName ?? 'Chat'),
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
                      reverse: true, // Show newest at bottom
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderId == currentUser?.uid;
                        
                        return _MessageBubble(
                          message: message,
                          isMe: isMe,
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
                 // Allow initiator to send messages? Usually yes, until blocked. 
                 // Or maybe limit to 1 message? 
                 // For now, let's allow them to write, but show the banner.
                 // Actually, standard practice is: you can write, but they won't see it until accepted?
                 // Or you can't write more?
                 // Let's allow writing for now, as it's "pending".
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
    return Container(
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
              onPressed: () {
                // TODO: Attachments
              },
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Scrivi un messaggio...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: AppColors.primary),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const _MessageBubble({
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
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
        child: Text(
          message.text,
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
