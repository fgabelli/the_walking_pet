import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ModerationWidget extends StatefulWidget {
  const ModerationWidget({super.key});

  @override
  State<ModerationWidget> createState() => _ModerationWidgetState();
}

class _ModerationWidgetState extends State<ModerationWidget> {
  String _filter = 'all'; // all, reported, flagged, removed, approved

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter chips
        Row(
          children: [
            _FilterChip(label: 'Tutti', value: 'all', selected: _filter, onSelected: _setFilter),
            const SizedBox(width: 8),
            _FilterChip(label: 'Segnalati', value: 'reported', selected: _filter, onSelected: _setFilter, badgeColor: Colors.red),
            const SizedBox(width: 8),
            _FilterChip(label: 'Flaggati AI', value: 'flagged', selected: _filter, onSelected: _setFilter),
            const SizedBox(width: 8),
            _FilterChip(label: 'Rimossi', value: 'removed', selected: _filter, onSelected: _setFilter),
            const SizedBox(width: 8),
            _FilterChip(label: 'Approvati', value: 'approved', selected: _filter, onSelected: _setFilter),
          ],
        ),
        const SizedBox(height: 20),
        
        // Content
        Expanded(
          child: _filter == 'reported'
              ? _buildUserReports()
              : _buildModerationLog(),
        ),
      ],
    );
  }

  void _setFilter(String value) => setState(() => _filter = value);

  /// Build the view for user-submitted reports (from content_reports collection)
  Widget _buildUserReports() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('content_reports')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.green[300]),
                const SizedBox(height: 16),
                Text('Nessuna segnalazione!', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            return _UserReportRow(data: data, docId: docId, onAction: () => setState(() {}));
          },
        );
      },
    );
  }

  /// Build the moderation log view (AI flags, admin actions)
  Widget _buildModerationLog() {
    return StreamBuilder<QuerySnapshot>(
      stream: _buildModerationQuery(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // For "all" filter, also merge user reports
        List<QueryDocumentSnapshot> docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty && _filter == 'all') {
          // Also check content_reports for the "all" tab
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('content_reports')
                .orderBy('createdAt', descending: true)
                .limit(100)
                .snapshots(),
            builder: (context, reportsSnapshot) {
              if (reportsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final reportDocs = reportsSnapshot.data?.docs ?? [];
              if (reportDocs.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.separated(
                itemCount: reportDocs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final data = reportDocs[index].data() as Map<String, dynamic>;
                  final docId = reportDocs[index].id;
                  return _UserReportRow(data: data, docId: docId, onAction: () => setState(() {}));
                },
              );
            },
          );
        }

        if (docs.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
            return _ModerationRow(data: data, docId: docId, onAction: () => setState(() {}));
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.green[300]),
          const SizedBox(height: 16),
          Text('Nessun post da moderare!', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _buildModerationQuery() {
    final base = FirebaseFirestore.instance.collection('moderation_log').orderBy('timestamp', descending: true).limit(100);
    
    if (_filter == 'flagged') return base.where('action', isEqualTo: 'flag').snapshots();
    if (_filter == 'removed') return base.where('action', isEqualTo: 'remove').snapshots();
    if (_filter == 'approved') return base.where('action', isEqualTo: 'approve').snapshots();
    return base.snapshots();
  }
}

/// Row for user-submitted reports (from content_reports)
class _UserReportRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final VoidCallback onAction;

  const _UserReportRow({required this.data, required this.docId, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final status = data['status'] ?? 'pending';
    final reason = data['reason'] ?? '';
    final details = data['details'] ?? '';
    final reporterName = data['reporterName'] ?? 'Utente';
    final postId = data['postId'] ?? '';
    final ts = data['createdAt'] as Timestamp?;
    final date = ts != null 
        ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year} ${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2, '0')}'
        : '—';

    Color statusColor;
    String statusLabel;
    
    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        statusLabel = 'In attesa';
        break;
      case 'reviewed':
        statusColor = Colors.green;
        statusLabel = 'Revisionato';
        break;
      case 'dismissed':
        statusColor = Colors.grey;
        statusLabel = 'Archiviato';
        break;
      default:
        statusColor = Colors.orange;
        statusLabel = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: status == 'pending' ? Colors.red.withOpacity(0.03) : null,
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.report, color: Colors.red, size: 20),
          ),
          const SizedBox(width: 16),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: const Text('Segnalazione utente', style: TextStyle(fontSize: 11, color: Colors.red)),
                    ),
                    const Spacer(),
                    Text(date, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Motivo: $reason', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(details, style: TextStyle(fontSize: 12, color: Colors.grey[600]), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 2),
                Text('Segnalato da: $reporterName • Post ID: $postId', style: TextStyle(fontSize: 10, color: Colors.grey[400], fontFamily: 'monospace')),
              ],
            ),
          ),
          
          // Actions for pending reports
          if (status == 'pending') ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              tooltip: 'Archivia (OK)',
              onPressed: () => _dismissReport(context),
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              tooltip: 'Rimuovi post',
              onPressed: () => _removePost(context),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _dismissReport(BuildContext context) async {
    try {
      await FirebaseFirestore.instance.collection('content_reports').doc(docId).update({
        'status': 'dismissed',
      });
      onAction();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Segnalazione archiviata')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  Future<void> _removePost(BuildContext context) async {
    try {
      final postId = data['postId'] ?? '';
      final collection = data['collection'] ?? 'social_posts';
      
      if (postId.isNotEmpty) {
        await _physicalDeleteContent(collection, postId);
      }
      
      // Mark report as reviewed
      await FirebaseFirestore.instance.collection('content_reports').doc(docId).update({
        'status': 'reviewed',
      });

      // Also log in moderation_log for audit trail
      await FirebaseFirestore.instance.collection('moderation_log').add({
        'action': 'remove',
        'contentType': 'social_post',
        'contentId': postId,
        'reason': 'User report: ${data['reason'] ?? ''}',
        'source': 'admin_review',
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      onAction();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post eliminato definitivamente e segnalazione chiusa')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final Function(String) onSelected;
  final Color? badgeColor;

  const _FilterChip({required this.label, required this.value, required this.selected, required this.onSelected, this.badgeColor});

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onSelected(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? (badgeColor ?? Colors.indigo) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[700], fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }
}

class _ModerationRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final VoidCallback onAction;

  const _ModerationRow({required this.data, required this.docId, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final action = data['action'] ?? 'unknown';
    final contentType = data['contentType'] ?? 'post';
    final reason = data['reason'] ?? '';
    final contentId = data['contentId'] ?? '';
    final ts = data['timestamp'] as Timestamp?;
    final date = ts != null 
        ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year} ${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2, '0')}'
        : '—';

    Color actionColor;
    IconData actionIcon;
    String actionLabel;
    
    switch (action) {
      case 'remove':
        actionColor = Colors.red;
        actionIcon = Icons.delete;
        actionLabel = 'Rimosso';
        break;
      case 'flag':
        actionColor = Colors.orange;
        actionIcon = Icons.flag;
        actionLabel = 'Segnalato';
        break;
      case 'approve':
        actionColor = Colors.green;
        actionIcon = Icons.check;
        actionLabel = 'Approvato';
        break;
      default:
        actionColor = Colors.grey;
        actionIcon = Icons.help_outline;
        actionLabel = action;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: action == 'flag' ? Colors.orange.withOpacity(0.03) : null,
      child: Row(
        children: [
          // Action badge
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: actionColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(actionIcon, color: actionColor, size: 20),
          ),
          const SizedBox(width: 16),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: actionColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(actionLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: actionColor)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
                      child: Text(contentType, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ),
                    const Spacer(),
                    Text(date, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                  ],
                ),
                if (reason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(reason, style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 2),
                Text('ID: $contentId', style: TextStyle(fontSize: 10, color: Colors.grey[400], fontFamily: 'monospace')),
              ],
            ),
          ),
          
          // Quick actions for flagged items
          if (action == 'flag') ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              tooltip: 'Approva',
              onPressed: () => _updateAction(context, 'approve'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              tooltip: 'Rimuovi',
              onPressed: () => _updateAction(context, 'remove'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _updateAction(BuildContext context, String newAction) async {
    try {
      await FirebaseFirestore.instance.collection('moderation_log').doc(docId).update({'action': newAction});
      
      // If removing, physically delete the content
      if (newAction == 'remove') {
        final contentType = data['contentType'] ?? '';
        final contentId = data['contentId'] ?? '';
        final collection = _collectionForType(contentType);
        if (collection != null && contentId.isNotEmpty) {
          await _physicalDeleteContent(collection, contentId);
        }
      }
      
      onAction();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(newAction == 'approve' ? 'Contenuto approvato' : 'Contenuto rimosso definitivamente')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  String? _collectionForType(String type) {
    switch (type) {
      case 'social_post': return 'social_posts';
      case 'announcement': return 'announcements';
      case 'comment': return 'comments';
      case 'chat': return 'chats';
      default: return null;
    }
  }
}

/// Helper to physically delete documents and subcollections (like comments)
Future<void> _physicalDeleteContent(String collection, String docId) async {
  final docRef = FirebaseFirestore.instance.collection(collection).doc(docId);
  
  // If it's a social post, delete comments first
  if (collection == 'social_posts') {
    final comments = await docRef.collection('comments').get();
    for (final doc in comments.docs) {
      await doc.reference.delete();
    }
  }
  
  await docRef.delete();
}

