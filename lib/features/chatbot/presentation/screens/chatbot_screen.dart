import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_colors.dart';

/// In-app AI Chatbot screen for DOGZN
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  static const _apiUrl = 'https://api-ivufbp6etq-uc.a.run.app/api/v1/chatbot';
  static const _project = 'dogzn';

  /// Deep knowledge base injected as system context
  static const _systemContext = '''
Sei l'assistente ufficiale DOGZN, l'app italiana per proprietari di animali domestici. Rispondi SOLO sulla base di queste informazioni. Non inventare funzionalità.

## FUNZIONALITÀ PRINCIPALI
- **Mappa interattiva**: mostra utenti nelle vicinanze, veterinari, negozi, toelettatori, dog park, educatori cinofili. Filtri per categoria.
- **Radar Mode**: vedi quanti utenti sono in zona senza mostrare la tua posizione esatta. Puoi inviare un "ping" per far sapere che ci sei.
- **Passeggiate GPS**: traccia percorso, distanza, durata, passi e calorie. Si sincronizza con Apple Health / Health Connect.
- **Walk Card**: al termine di ogni passeggiata, viene generata una card condivisibile (Instagram, WhatsApp) con le statistiche.
- **Chat 1:1**: messaggi diretti con altri utenti. Supporta foto, posizione, inviti a passeggiata e profili pet.
- **Bacheca locale (Nextdoor)**: annunci geolocalizzati — cerchi dog sitter, hai trovato un oggetto, vendi accessori.
- **SOS Smarrimento**: lancia un allarme che notifica tutti gli utenti nel raggio di 5 km. Include foto, nome e contatto.
- **Segnalazione pericoli**: bocconi avvelenati, zone pericolose — segnala con un tap dalla mappa.
- **Profilo Pet**: foto, razza, data di nascita, microchip e scheda sanitaria (vaccini, farmaci, visite, allergie).
- **Social Feed**: post con foto, like, commenti — visibili agli amici e alla community locale.
- **Eventi**: raduni al parco, passeggiate di gruppo, fiere pet-friendly.

## RISCATTO ATTIVITÀ (Business Claim)
Per riscattare un'attività (veterinario, negozio, toelettatore, ecc.):
1. Vai sulla **Mappa** e trova il marker dell'attività
2. Tocca il marker per aprire la scheda
3. Scorri in basso e premi **"Riscatta questa attività"**
4. Compila il modulo con: nome, cognome, ruolo nell'attività, email aziendale, P.IVA
5. Il team DOGZN verifica la richiesta e la approva (riceverai una notifica)
6. Una volta approvato, puoi gestire il profilo business, rispondere alle recensioni e pubblicare offerte

## PIANI E PREZZI
- **Free** (€0): Radar, passeggiate (ultime 7), chat, bacheca, SOS. Con pubblicità.
- **Premium** (€2.99/mese): tutto del Free + zero pubblicità, cronologia illimitata, badge Premium, statistiche avanzate.
- **Business** (€9.99/mese): tutto del Premium + profilo business in evidenza, promozioni localizzate, statistiche business, risposte alle recensioni.

## PUBBLICITÀ IN-APP
Se vuoi pubblicizzare la tua attività su DOGZN:
1. Vai su **dogzn.com**, sezione "Business"
2. Compila il modulo di richiesta
3. Il team ti contatta entro 24 ore
Oppure scrivi a **business@dogzn.com**

## SUPPORTO
- Email: support@dogzn.com
- Business: business@dogzn.com
- L'app è disponibile su App Store e Google Play

## REGOLE
- Rispondi sempre in italiano
- Sii conciso e amichevole
- Se non sai qualcosa, dì di contattare support@dogzn.com
- Non inventare funzionalità che non esistono
''';

  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _sessionId = const Uuid().v4();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMessage(
      text: 'Ciao! 🐕 Sono l\'assistente DOGZN. Come posso aiutarti?',
      isUser: false,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    _controller.clear();
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      // Build history (last 10 messages)
      final history = _messages
          .take(_messages.length > 10 ? _messages.length : 10)
          .map((m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'text': m.text,
              })
          .toList();

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'project': _project,
          'message': text,
          'sessionId': _sessionId,
          'history': [
            // Inject system knowledge as first entry
            {'role': 'system', 'text': _systemContext},
            ...history,
          ],
        }),
      );

      final data = jsonDecode(response.body);
      setState(() {
        if (data['status'] == 'ok') {
          _messages.add(_ChatMessage(text: data['response'], isUser: false));
        } else {
          _messages.add(_ChatMessage(
            text: data['message'] ?? 'Si è verificato un errore. Riprova.',
            isUser: false,
          ));
        }
      });
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(
          text: 'Connessione non riuscita. Verifica la tua connessione e riprova.',
          isUser: false,
        ));
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🐕', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('DOGZN Assistant'),
          ],
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return const _TypingIndicator();
                }
                return _MessageBubble(message: _messages[index]);
              },
            ),
          ),

          // Input
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 8,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLength: 500,
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Scrivi un messaggio...',
                      counterText: '',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _isLoading ? null : _sendMessage,
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  _ChatMessage({
    required this.text,
    required this.isUser,
  }) : timestamp = DateTime.now();
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: message.isUser
              ? AppColors.primary
              : Colors.grey[100],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(message.isUser ? 18 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 18),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
            color: message.isUser ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      return AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      )..repeat(reverse: true);
    });

    for (var i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) _controllers[i].forward();
      });
    }

    _animations = _controllers.map((c) {
      return Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _animations[i],
              builder: (_, __) => Transform.translate(
                offset: Offset(0, _animations[i].value),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
