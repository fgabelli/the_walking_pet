import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart';

/// Widget per la gestione dei template messaggi e l'invio broadcast alla community.
class BroadcastTemplatesWidget extends StatefulWidget {
  const BroadcastTemplatesWidget({super.key});

  @override
  State<BroadcastTemplatesWidget> createState() => _BroadcastTemplatesWidgetState();
}

class _BroadcastTemplatesWidgetState extends State<BroadcastTemplatesWidget> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            tabs: const [
              Tab(icon: Icon(Icons.description_outlined), text: 'Template'),
              Tab(icon: Icon(Icons.send_outlined), text: 'Invia Broadcast'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _TemplateManagementTab(),
              _BroadcastSendTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// TAB 1: Gestione Template
// =============================================================================

class _TemplateManagementTab extends StatelessWidget {
  const _TemplateManagementTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header con pulsante "Nuovo Template"
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              onPressed: () => _showTemplateDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Nuovo Template'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Lista template
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('message_templates')
                .orderBy('updatedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text('Errore nel caricamento dei template', style: TextStyle(fontSize: 14, color: Colors.red[400])),
                      const SizedBox(height: 8),
                      SelectableText('${snapshot.error}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('Nessun template creato', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                      const SizedBox(height: 8),
                      Text('Crea il tuo primo template per iniziare!', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                    ],
                  ),
                );
              }

              final templates = snapshot.data!.docs;
              return ListView.builder(
                itemCount: templates.length,
                itemBuilder: (context, index) {
                  final doc = templates[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final title = data['title'] ?? 'Senza titolo';
                  final body = data['body'] ?? '';
                  final tags = (data['tags'] as List<dynamic>?)?.cast<String>() ?? [];
                  final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                child: const Icon(Icons.description, color: AppColors.primary, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                    if (updatedAt != null)
                                      Text(
                                        'Modificato: ${updatedAt.day}/${updatedAt.month}/${updatedAt.year} ${updatedAt.hour.toString().padLeft(2, '0')}:${updatedAt.minute.toString().padLeft(2, '0')}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                      ),
                                  ],
                                ),
                              ),
                              // Azioni
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                                tooltip: 'Modifica template',
                                onPressed: () => _showTemplateDialog(context, docId: doc.id, existingData: data),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                tooltip: 'Elimina template',
                                onPressed: () => _confirmDelete(context, doc.id, title),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Anteprima del corpo del messaggio
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: _buildHighlightedText(body),
                          ),
                          if (tags.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: tags.map((tag) => Chip(
                                label: Text(tag, style: const TextStyle(fontSize: 11)),
                                backgroundColor: AppColors.primary.withOpacity(0.08),
                                labelStyle: const TextStyle(color: AppColors.primary),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              )).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Evidenzia i tag nel testo con un colore diverso
  static Widget _buildHighlightedText(String text) {
    final tagPattern = RegExp(r'\{\{[^}]+\}\}');
    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in tagPattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          backgroundColor: Color(0x150A2342),
        ),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 13, color: Colors.grey[800], height: 1.5),
        children: spans,
      ),
    );
  }

  /// Dialog per creare/modificare un template
  static void _showTemplateDialog(BuildContext context, {String? docId, Map<String, dynamic>? existingData}) {
    final titleController = TextEditingController(text: existingData?['title'] ?? '');
    final bodyController = TextEditingController(text: existingData?['body'] ?? '');
    final isEditing = docId != null;

    final availableTags = [
      '{{nome}}',
      '{{cognome}}',
      '{{nome_completo}}',
      '{{nome_cane}}',
      '{{razza_cane}}',
      '{{specie}}',
      '{{città}}',
      '{{zona}}',
      '{{piano}}',
      '{{tipo_account}}',
      '{{genere}}',
    ];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Icon(
                      isEditing ? Icons.edit : Icons.add_circle_outline,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEditing ? 'Modifica Template' : 'Nuovo Template',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Titolo
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: 'Titolo del template',
                          hintText: 'Es: Benvenuto nuovo utente',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          prefixIcon: const Icon(Icons.title),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Corpo messaggio
                      TextField(
                        controller: bodyController,
                        maxLines: 6,
                        decoration: InputDecoration(
                          labelText: 'Corpo del messaggio',
                          hintText: 'Scrivi il messaggio qui. Usa i tag qui sotto per personalizzarlo.',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Barra tag cliccabili
                      Text('Inserisci tag:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: availableTags.map((tag) => ActionChip(
                          label: Text(tag, style: const TextStyle(fontSize: 11)),
                          backgroundColor: AppColors.primary.withOpacity(0.08),
                          labelStyle: const TextStyle(color: AppColors.primary),
                          onPressed: () {
                            final cursorPos = bodyController.selection.baseOffset;
                            final currentText = bodyController.text;
                            final insertPos = cursorPos >= 0 ? cursorPos : currentText.length;
                            final newText = currentText.substring(0, insertPos) + tag + currentText.substring(insertPos);
                            bodyController.text = newText;
                            bodyController.selection = TextSelection.collapsed(offset: insertPos + tag.length);
                          },
                        )).toList(),
                      ),
                      const SizedBox(height: 20),
                      // Anteprima live
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Anteprima (con dati di esempio):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                            const SizedBox(height: 8),
                            Text(
                              _previewMessage(bodyController.text),
                              style: TextStyle(fontSize: 13, color: Colors.grey[800], height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annulla'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final body = bodyController.text.trim();
                    if (title.isEmpty || body.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Titolo e corpo sono obbligatori'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    // Estrai i tag usati nel corpo
                    final usedTags = RegExp(r'\{\{[^}]+\}\}')
                        .allMatches(body)
                        .map((m) => m.group(0)!)
                        .toSet()
                        .toList();

                    final templateData = {
                      'title': title,
                      'body': body,
                      'tags': usedTags,
                      'updatedAt': FieldValue.serverTimestamp(),
                      if (!isEditing) 'createdAt': FieldValue.serverTimestamp(),
                      if (!isEditing) 'createdBy': FirebaseAuth.instance.currentUser?.uid ?? '',
                    };

                    try {
                      if (isEditing) {
                        await FirebaseFirestore.instance.collection('message_templates').doc(docId).update(templateData);
                      } else {
                        await FirebaseFirestore.instance.collection('message_templates').add(templateData);
                      }
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  icon: Icon(isEditing ? Icons.save : Icons.add),
                  label: Text(isEditing ? 'Salva Modifiche' : 'Crea Template'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Sostituisce i tag con dati di esempio per l'anteprima
  static String _previewMessage(String template) {
    const exampleData = {
      '{{nome}}': 'Mario',
      '{{cognome}}': 'Rossi',
      '{{nome_completo}}': 'Mario Rossi',
      '{{nome_cane}}': 'Luna',
      '{{razza_cane}}': 'Golden Retriever',
      '{{specie}}': 'Cane',
      '{{città}}': 'Milano',
      '{{zona}}': 'Navigli',
      '{{piano}}': 'Free',
      '{{tipo_account}}': 'Personale',
      '{{genere}}': 'Uomo',
    };
    String result = template;
    exampleData.forEach((tag, value) {
      result = result.replaceAll(tag, value);
    });
    return result;
  }

  /// Conferma eliminazione template
  static void _confirmDelete(BuildContext context, String docId, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina Template'),
        content: Text('Sei sicuro di voler eliminare il template "$title"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('message_templates').doc(docId).delete();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TAB 2: Invio Broadcast
// =============================================================================

class _BroadcastSendTab extends StatefulWidget {
  const _BroadcastSendTab();

  @override
  State<_BroadcastSendTab> createState() => _BroadcastSendTabState();
}

class _BroadcastSendTabState extends State<_BroadcastSendTab> {
  final TextEditingController _messageController = TextEditingController();
  String? _selectedTemplateId;
  bool _isSending = false;
  Map<String, dynamic>? _sendResult;

  // Modalità selezione destinatari
  bool _manualSelection = false; // false = filtri, true = selezione manuale
  final Set<String> _selectedUserIds = {};
  String _searchQuery = '';

  // Filtri
  String? _filterCity;
  bool? _filterIsPremium;
  String? _filterAccountType;
  String? _filterGender;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sezione 1: Selezione template
          _buildSectionCard(
            title: '1. Seleziona Template o Scrivi Messaggio',
            icon: Icons.message_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dropdown template
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('message_templates')
                      .orderBy('updatedAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final templates = snapshot.data?.docs ?? [];
                    return DropdownButtonFormField<String>(
                      value: _selectedTemplateId,
                      decoration: InputDecoration(
                        labelText: 'Seleziona un template',
                        hintText: 'Oppure scrivi un messaggio libero qui sotto',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.description),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('— Nessun template (testo libero) —')),
                        ...templates.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return DropdownMenuItem(value: doc.id, child: Text(data['title'] ?? 'Senza titolo'));
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedTemplateId = value;
                          if (value != null) {
                            final doc = templates.firstWhere((d) => d.id == value);
                            final data = doc.data() as Map<String, dynamic>;
                            _messageController.text = data['body'] ?? '';
                          }
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Campo messaggio
                TextField(
                  controller: _messageController,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: 'Messaggio',
                    hintText: 'Scrivi qui il testo del broadcast. Puoi usare i tag per personalizzarlo.',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    alignLabelWithHint: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                // Barra tag cliccabili
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    '{{nome}}', '{{cognome}}', '{{nome_completo}}', '{{nome_cane}}',
                    '{{razza_cane}}', '{{specie}}', '{{città}}', '{{zona}}',
                    '{{piano}}', '{{tipo_account}}', '{{genere}}',
                  ].map((tag) => ActionChip(
                    label: Text(tag, style: const TextStyle(fontSize: 10)),
                    backgroundColor: AppColors.primary.withOpacity(0.08),
                    labelStyle: const TextStyle(color: AppColors.primary),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      final cursorPos = _messageController.selection.baseOffset;
                      final currentText = _messageController.text;
                      final insertPos = cursorPos >= 0 ? cursorPos : currentText.length;
                      final newText = currentText.substring(0, insertPos) + tag + currentText.substring(insertPos);
                      _messageController.text = newText;
                      _messageController.selection = TextSelection.collapsed(offset: insertPos + tag.length);
                      setState(() {});
                    },
                  )).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sezione 2: Destinatari
          _buildSectionCard(
            title: '2. Seleziona Destinatari',
            icon: Icons.people_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Toggle modalità
                Row(
                  children: [
                    Expanded(
                      child: _buildModeButton(
                        label: 'Tutti (con filtri)',
                        icon: Icons.filter_alt_outlined,
                        isSelected: !_manualSelection,
                        onTap: () => setState(() {
                          _manualSelection = false;
                          _selectedUserIds.clear();
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildModeButton(
                        label: 'Seleziona utenti',
                        icon: Icons.person_add_outlined,
                        isSelected: _manualSelection,
                        onTap: () => setState(() => _manualSelection = true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Contenuto condizionale
                if (!_manualSelection) ...[
                  // Filtri
                  Row(
                    children: [
                      Expanded(
                        child: _buildFilterField(
                          label: 'Città',
                          value: _filterCity,
                          onChanged: (v) => setState(() => _filterCity = v?.isEmpty == true ? null : v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<bool?>(
                          value: _filterIsPremium,
                          decoration: InputDecoration(
                            labelText: 'Piano',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('Tutti')),
                            DropdownMenuItem(value: false, child: Text('Free')),
                            DropdownMenuItem(value: true, child: Text('Premium')),
                          ],
                          onChanged: (v) => setState(() => _filterIsPremium = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: _filterAccountType,
                          decoration: InputDecoration(
                            labelText: 'Tipo Account',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('Tutti')),
                            DropdownMenuItem(value: 'personal', child: Text('Personale')),
                            DropdownMenuItem(value: 'business', child: Text('Business')),
                          ],
                          onChanged: (v) => setState(() => _filterAccountType = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: _filterGender,
                          decoration: InputDecoration(
                            labelText: 'Genere',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('Tutti')),
                            DropdownMenuItem(value: 'male', child: Text('Uomo')),
                            DropdownMenuItem(value: 'female', child: Text('Donna')),
                          ],
                          onChanged: (v) => setState(() => _filterGender = v),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Selezione manuale utenti
                  _buildUserSelectionList(),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sezione 3: Anteprima e Conteggio destinatari
          _buildSectionCard(
            title: '3. Anteprima e Invio',
            icon: Icons.preview_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Anteprima messaggio con dati di esempio
                if (_messageController.text.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.visibility, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text('Anteprima (dati di esempio):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _previewBroadcastMessage(_messageController.text),
                          style: TextStyle(fontSize: 13, color: Colors.grey[800], height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Conteggio destinatari live
                _buildRecipientCount(),
                const SizedBox(height: 16),

                // Pulsante invio + risultato
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isSending || _messageController.text.trim().isEmpty || (_manualSelection && _selectedUserIds.isEmpty)
                          ? null
                          : () => _confirmAndSend(context),
                      icon: _isSending
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send),
                      label: Text(_isSending ? 'Invio in corso...' : 'Invia Broadcast'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (_sendResult != null) ...[
                      const SizedBox(width: 20),
                      _buildResultBadge(),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Card wrapper per sezioni
  Widget _buildSectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  /// Campo di filtro testuale
  Widget _buildFilterField({required String label, String? value, required ValueChanged<String?> onChanged}) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Qualsiasi',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      onChanged: onChanged,
    );
  }

  /// Pulsante toggle per la modalità di selezione
  Widget _buildModeButton({required String label, required IconData icon, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? AppColors.primary : Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Lista utenti con checkbox per selezione manuale
  Widget _buildUserSelectionList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Barra di ricerca
        TextField(
          decoration: InputDecoration(
            hintText: 'Cerca utente per nome, cognome o email...',
            prefixIcon: const Icon(Icons.search, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        ),
        const SizedBox(height: 8),
        // Azioni rapide
        Row(
          children: [
            TextButton.icon(
              onPressed: () => setState(() {
                // Seleziona tutti visibili verrà gestito nel builder
                _selectAllVisible = true;
              }),
              icon: const Icon(Icons.select_all, size: 16),
              label: const Text('Seleziona tutti', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _selectedUserIds.clear()),
              icon: const Icon(Icons.deselect, size: 16),
              label: const Text('Deseleziona tutti', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _selectedUserIds.isNotEmpty ? AppColors.primary.withOpacity(0.1) : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${_selectedUserIds.length} selezionati',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _selectedUserIds.isNotEmpty ? AppColors.primary : Colors.grey[500],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Lista utenti
        SizedBox(
          height: 300,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final allUsers = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                if (doc.id == 'DOGZN') return false;
                if (data['accountType'] == 'system') return false;
                if (data['isBanned'] == true) return false;
                return true;
              }).toList();

              // Gestione "seleziona tutti"
              if (_selectAllVisible) {
                _selectAllVisible = false;
                for (final doc in allUsers) {
                  _selectedUserIds.add(doc.id);
                }
              }

              // Applica ricerca
              final filteredUsers = allUsers.where((doc) {
                if (_searchQuery.isEmpty) return true;
                final data = doc.data() as Map<String, dynamic>;
                final firstName = (data['firstName'] as String? ?? '').toLowerCase();
                final lastName = (data['lastName'] as String? ?? '').toLowerCase();
                final email = (data['email'] as String? ?? '').toLowerCase();
                return firstName.contains(_searchQuery) ||
                    lastName.contains(_searchQuery) ||
                    email.contains(_searchQuery);
              }).toList();

              if (filteredUsers.isEmpty) {
                return Center(
                  child: Text('Nessun utente trovato', style: TextStyle(color: Colors.grey[500])),
                );
              }

              return ListView.builder(
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  final doc = filteredUsers[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final firstName = data['firstName'] as String? ?? '';
                  final lastName = data['lastName'] as String? ?? '';
                  final email = data['email'] as String? ?? '';
                  final city = data['city'] as String? ?? '';
                  final photoUrl = data['photoUrl'] as String?;
                  final isPremium = data['isPremium'] == true;
                  final isSelected = _selectedUserIds.contains(doc.id);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withOpacity(0.05) : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CheckboxListTile(
                      value: isSelected,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedUserIds.add(doc.id);
                          } else {
                            _selectedUserIds.remove(doc.id);
                          }
                        });
                      },
                      activeColor: AppColors.primary,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      secondary: CircleAvatar(
                        radius: 16,
                        backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                            ? NetworkImage(photoUrl)
                            : null,
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: photoUrl == null || photoUrl.isEmpty
                            ? Text(
                                firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
                                style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      title: Text(
                        '$firstName $lastName'.trim(),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Row(
                        children: [
                          Flexible(
                            child: Text(
                              email,
                              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (city.isNotEmpty) ...[
                            Text(' · ', style: TextStyle(color: Colors.grey[400])),
                            Text(city, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                          ],
                          if (isPremium) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('PRO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  bool _selectAllVisible = false;

  /// Conteggio destinatari live basato sui filtri o selezione manuale
  Widget _buildRecipientCount() {
    // In modalità selezione manuale, mostra il conteggio dei selezionati
    if (_manualSelection) {
      final count = _selectedUserIds.length;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: count > 0 ? Colors.green.withOpacity(0.08) : Colors.orange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: count > 0 ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people, size: 18, color: count > 0 ? Colors.green[700] : Colors.orange[700]),
            const SizedBox(width: 8),
            Text(
              '$count utenti selezionati',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: count > 0 ? Colors.green[700] : Colors.orange[700],
              ),
            ),
          ],
        ),
      );
    }

    // In modalità filtri, conteggio live da Firestore
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('users');

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Text('Calcolando destinatari...', style: TextStyle(color: Colors.grey[500], fontSize: 13));
        }

        int count = 0;
        for (final doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (doc.id == 'DOGZN') continue;
          if (data['accountType'] == 'system') continue;
          if (data['isBanned'] == true) continue;

          if (_filterCity != null && _filterCity!.isNotEmpty) {
            final userCity = (data['city'] as String?)?.toLowerCase() ?? '';
            if (!userCity.contains(_filterCity!.toLowerCase())) continue;
          }
          if (_filterIsPremium != null) {
            if ((data['isPremium'] ?? false) != _filterIsPremium) continue;
          }
          if (_filterAccountType != null) {
            if (data['accountType'] != _filterAccountType) continue;
          }
          if (_filterGender != null) {
            if (data['gender'] != _filterGender) continue;
          }
          count++;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: count > 0 ? Colors.green.withOpacity(0.08) : Colors.orange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: count > 0 ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people, size: 18, color: count > 0 ? Colors.green[700] : Colors.orange[700]),
              const SizedBox(width: 8),
              Text(
                '$count destinatari',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: count > 0 ? Colors.green[700] : Colors.orange[700],
                ),
              ),
              if (_hasActiveFilters) ...[
                const SizedBox(width: 8),
                Text('(filtro attivo)', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ],
          ),
        );
      },
    );
  }

  bool get _hasActiveFilters =>
      _filterCity != null || _filterIsPremium != null || _filterAccountType != null || _filterGender != null;

  bool get _hasRecipients => _manualSelection ? _selectedUserIds.isNotEmpty : true;

  /// Badge risultato invio
  Widget _buildResultBadge() {
    final sent = _sendResult?['sentCount'] ?? 0;
    final failed = _sendResult?['failedCount'] ?? 0;
    final total = _sendResult?['totalTargeted'] ?? 0;
    final success = _sendResult?['success'] == true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: success ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: success ? Colors.green : Colors.red),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(success ? Icons.check_circle : Icons.error, size: 18, color: success ? Colors.green : Colors.red),
          const SizedBox(width: 8),
          Text(
            'Inviati: $sent/$total${failed > 0 ? ' (falliti: $failed)' : ''}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: success ? Colors.green[800] : Colors.red[800]),
          ),
        ],
      ),
    );
  }

  /// Anteprima con dati fittizi
  String _previewBroadcastMessage(String template) {
    const exampleData = {
      '{{nome}}': 'Mario',
      '{{cognome}}': 'Rossi',
      '{{nome_completo}}': 'Mario Rossi',
      '{{nome_cane}}': 'Luna',
      '{{razza_cane}}': 'Golden Retriever',
      '{{specie}}': 'Cane',
      '{{città}}': 'Milano',
      '{{zona}}': 'Navigli',
      '{{piano}}': 'Free',
      '{{tipo_account}}': 'Personale',
      '{{genere}}': 'Uomo',
    };
    String result = template;
    exampleData.forEach((tag, value) {
      result = result.replaceAll(tag, value);
    });
    return result;
  }

  /// Conferma e invio broadcast
  void _confirmAndSend(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
        title: const Text('Conferma Invio Broadcast'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Stai per inviare un messaggio a tutti gli utenti selezionati. '
              'Ogni utente riceverà il messaggio personalizzato nella propria chat con DOGZN.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Questa azione non può essere annullata.',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[700]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _sendBroadcast();
            },
            icon: const Icon(Icons.send),
            label: const Text('Conferma Invio'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  /// Invio effettivo del broadcast
  Future<void> _sendBroadcast() async {
    setState(() {
      _isSending = true;
      _sendResult = null;
    });

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('adminBroadcastMessage');

      final targetFilter = <String, dynamic>{};
      if (_filterCity != null && _filterCity!.isNotEmpty) targetFilter['city'] = _filterCity;
      if (_filterIsPremium != null) targetFilter['isPremium'] = _filterIsPremium;
      if (_filterAccountType != null) targetFilter['accountType'] = _filterAccountType;
      if (_filterGender != null) targetFilter['gender'] = _filterGender;

      final result = await callable.call({
        'messageTemplate': _messageController.text.trim(),
        'targetFilter': targetFilter.isEmpty ? null : targetFilter,
        if (_manualSelection && _selectedUserIds.isNotEmpty)
          'targetUserIds': _selectedUserIds.toList(),
      });

      setState(() {
        _sendResult = Map<String, dynamic>.from(result.data as Map);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Broadcast completato! Inviati: ${_sendResult?['sentCount'] ?? 0} messaggi.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _sendResult = {'success': false, 'sentCount': 0, 'failedCount': 0, 'totalTargeted': 0};
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }
}
