import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/review_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/review_model.dart';
import 'package:the_walking_pet/features/auth/presentation/providers/auth_provider.dart';
import 'package:the_walking_pet/features/profile/presentation/providers/profile_provider.dart';

final reviewServiceProvider = Provider((ref) => ReviewService());

class CreateReviewScreen extends ConsumerStatefulWidget {
  final String announcementId;
  final String announcementTitle;
  final String targetUserId;

  const CreateReviewScreen({
    super.key,
    required this.announcementId,
    required this.announcementTitle,
    required this.targetUserId,
  });

  @override
  ConsumerState<CreateReviewScreen> createState() => _CreateReviewScreenState();
}

class _CreateReviewScreenState extends ConsumerState<CreateReviewScreen> {
  final _commentController = TextEditingController();
  double _rating = 5.0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submitReview() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scrivi un commento per la tua recensione')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userAsync = ref.read(currentUserProfileProvider);
      final user = userAsync.value;
      
      if (user == null) throw Exception('Utente non autenticato o profilo non caricato');

      final review = ReviewModel(
        id: '', // Firestore generates ID
        authorId: user.uid,
        authorName: user.fullName,
        authorPhotoUrl: user.photoUrl,
        announcementId: widget.announcementId,
        targetUserId: widget.targetUserId,
        rating: _rating,
        comment: _commentController.text.trim(),
        timestamp: DateTime.now(),
      );

      await ref.read(reviewServiceProvider).addReview(review);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recensione inviata!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scrivi Recensione'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recensisci questo annuncio',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              widget.announcementTitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Come è stata la tua esperienza?',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 32),

            // Rating
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () {
                      setState(() => _rating = index + 1.0);
                    },
                    icon: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 40,
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 32),

            // Comment
            TextField(
              controller: _commentController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'La tua opinione',
                alignLabelWithHint: true,
                hintText: 'Scrivi qui la tua recensione...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReview,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Invia Recensione'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
