import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/chat_model.dart';
import '../providers/chat_provider.dart';
import 'chat_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../auth/presentation/providers/auth_provider.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(userChatsProvider);
    final currentUser = ref.watch(authServiceProvider).currentUser;

    if (currentUser == null) return const Center(child: Text('Utente non autenticato'));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Messaggi'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Messaggi'),
              Tab(text: 'Richieste'),
            ],
          ),
        ),
        body: chatsAsync.when(
          data: (chats) {
            // Filter chats
            final activeChats = chats.where((c) {
              return c.status == ChatStatus.accepted ||
                  (c.status == ChatStatus.pending && c.initiatorId == currentUser.uid);
            }).toList();

            final requestChats = chats.where((c) {
              return c.status == ChatStatus.pending && c.initiatorId != currentUser.uid;
            }).toList();

            return TabBarView(
              children: [
                _ChatList(chats: activeChats, emptyMessage: 'Nessuna conversazione attiva'),
                _ChatList(chats: requestChats, emptyMessage: 'Nessuna richiesta in sospeso'),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Errore: $e')),
        ),
      ),
    );
  }
}

class _ChatList extends StatelessWidget {
  final List<ChatModel> chats;
  final String emptyMessage;

  const _ChatList({required this.chats, required this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    if (chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(emptyMessage),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: chats.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final chat = chats[index];
        return _ChatListItem(chat: chat);
      },
    );
  }
}

class _ChatListItem extends ConsumerWidget {
  final ChatModel chat;

  const _ChatListItem({required this.chat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Fetch other participant's name/photo
    // For now, just show a placeholder or try to find it from participants
    // We need a way to know WHICH participant is the "other" one.
    // We can get current user from auth provider.
    
    // This logic should ideally be in a provider or view model
    
    return ListTile(
      leading: const CircleAvatar(
        child: Icon(Icons.person),
      ),
      title: const Text('Utente'), // Placeholder
      subtitle: Text(
        chat.lastMessage?.text ?? 'Inizia a chattare',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        timeago.format(chat.updatedAt, locale: 'it'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(chatId: chat.id),
          ),
        );
      },
    );
  }
}
