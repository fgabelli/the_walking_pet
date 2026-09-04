import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../shared/models/pet_business_model.dart';
import '../../../../shared/models/review_model.dart';
import '../../../../core/services/pet_business_service.dart';
import '../../../../core/services/review_service.dart';
import '../../../../core/theme/app_colors.dart';
import 'claim_business_screen.dart';

/// Full-page detail screen for a pet business or dog park
class PetBusinessDetailScreen extends ConsumerStatefulWidget {
  final PetBusinessModel business;
  const PetBusinessDetailScreen({super.key, required this.business});

  @override
  ConsumerState<PetBusinessDetailScreen> createState() => _PetBusinessDetailScreenState();
}

class _PetBusinessDetailScreenState extends ConsumerState<PetBusinessDetailScreen> {
  Map<String, dynamic>? _placeDetails;
  bool _loadingDetails = true;
  ReviewStats? _reviewStats;
  String? _claimStatus; // null, 'pending', 'approved', 'rejected'

  @override
  void initState() {
    super.initState();
    _loadDetails();
    _loadReviewStats();
    _loadClaimStatus();
  }

  Future<void> _loadClaimStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final status = await ref.read(petBusinessServiceProvider).getClaimStatus(
      businessId: widget.business.id,
      userId: user.uid,
    );
    if (mounted) setState(() => _claimStatus = status);
  }

  Future<void> _loadDetails() async {
    if (widget.business.googlePlaceId == null) {
      setState(() => _loadingDetails = false);
      return;
    }
    final details = await PetBusinessService().getPlaceDetails(widget.business.googlePlaceId!);
    if (mounted) {
      setState(() {
        _placeDetails = details;
        _loadingDetails = false;
      });
    }
  }

  Future<void> _loadReviewStats() async {
    final stats = await ref.read(reviewServiceProvider).getPetBusinessReviewStats(widget.business.id);
    if (mounted) setState(() => _reviewStats = stats);
  }

  @override
  Widget build(BuildContext context) {
    final biz = widget.business;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final phone = _placeDetails?['formatted_phone_number'] ?? biz.phone;
    final website = _placeDetails?['website'] ?? biz.website;
    final fullAddress = _placeDetails?['formatted_address'] ?? biz.address;
    final mapsUrl = _placeDetails?['url'];
    final openingHours = _placeDetails?['opening_hours']?['weekday_text'] as List?;
    final isDogPark = biz.category == PetBusinessCategory.dogPark || biz.category == PetBusinessCategory.petFriendlyBeach;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // Hero header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: _categoryColor(biz.category),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _categoryColor(biz.category),
                      _categoryColor(biz.category).withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            biz.category.icon,
                            style: const TextStyle(fontSize: 36),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          biz.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges row
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildBadge(
                        biz.category.displayName,
                        _categoryColor(biz.category),
                      ),
                      if (isDogPark)
                        _buildBadge('Spazio pubblico', const Color(0xFF43A047),
                            icon: Icons.nature_people),
                      if (biz.isClaimed)
                        _buildBadge('Verificato', Colors.green,
                            icon: Icons.verified),
                      if (biz.openNow != null)
                        _buildBadge(
                          biz.openNow == 'Aperto' ? 'Aperto ora' : 'Chiuso',
                          biz.openNow == 'Aperto' ? Colors.green : Colors.red,
                          icon: Icons.circle,
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Rating summary card
                  if (_reviewStats != null && _reviewStats!.totalReviews > 0)
                    _buildRatingSummaryCard(biz),
                  
                  const SizedBox(height: 16),

                  // Info card
                  _buildInfoCard(
                    isDark: isDark,
                    children: [
                      _buildInfoTile(Icons.location_on, fullAddress, onTap: () {
                        if (mapsUrl != null) launchUrl(Uri.parse(mapsUrl));
                      }),
                      if (phone != null) ...[
                        const Divider(height: 1),
                        _buildInfoTile(Icons.phone, phone, onTap: () {
                          launchUrl(Uri.parse('tel:$phone'));
                        }),
                      ],
                      if (website != null) ...[
                        const Divider(height: 1),
                        _buildInfoTile(Icons.language, website, onTap: () {
                          launchUrl(Uri.parse(website));
                        }),
                      ],
                    ],
                  ),

                  // Opening hours
                  if (openingHours != null) ...[
                    const SizedBox(height: 16),
                    _buildSectionTitle('Orari di apertura', Icons.schedule),
                    const SizedBox(height: 8),
                    _buildInfoCard(
                      isDark: isDark,
                      children: openingHours.map((day) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Text(
                          day.toString(),
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                      )).toList(),
                    ),
                  ],

                  // Description
                  if (biz.description != null && biz.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildSectionTitle('Descrizione', Icons.info_outline),
                    const SizedBox(height: 8),
                    _buildInfoCard(
                      isDark: isDark,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            biz.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.grey[300] : Colors.grey[700],
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Services
                  if (biz.services.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildSectionTitle('Servizi', Icons.check_circle_outline),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: biz.services.map((s) => Chip(
                        label: Text(s, style: const TextStyle(fontSize: 13)),
                        backgroundColor: _categoryColor(biz.category).withOpacity(0.1),
                        side: BorderSide(color: _categoryColor(biz.category).withOpacity(0.3)),
                      )).toList(),
                    ),
                  ],

                  // Action buttons
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      if (phone != null)
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.call,
                            label: 'Chiama',
                            color: Colors.green,
                            onTap: () => launchUrl(Uri.parse('tel:$phone')),
                          ),
                        ),
                      if (phone != null && mapsUrl != null) const SizedBox(width: 12),
                      if (mapsUrl != null)
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.directions,
                            label: 'Indicazioni',
                            color: AppColors.primary,
                            onTap: () => launchUrl(Uri.parse(mapsUrl)),
                          ),
                        ),
                    ],
                  ),

                  // Claim Business CTA
                  if (!biz.isClaimed && biz.category.canBeClaimed)
                    _buildClaimBusinessCTA(biz, isDark),

                  // Pending claim status
                  if (_claimStatus == 'pending')
                    _buildClaimStatusBanner('pending'),
                  if (_claimStatus == 'rejected')
                    _buildClaimStatusBanner('rejected'),

                  // Reviews section
                  const SizedBox(height: 32),
                  _buildSectionTitle('Recensioni', Icons.rate_review),
                  const SizedBox(height: 12),

                  // Write review button
                  _buildWriteReviewButton(biz),
                  const SizedBox(height: 16),

                  // Reviews stream
                  _buildReviewsList(biz),

                  const SizedBox(height: 32),

                  // Loading details
                  if (_loadingDetails)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================
  // RATING SUMMARY
  // ============================

  Widget _buildRatingSummaryCard(PetBusinessModel biz) {
    final stats = _reviewStats;
    final rating = stats?.averageRating ?? 0.0;
    final total = stats?.totalReviews ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Big rating number
          Column(
            children: [
              Text(
                rating.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              // Stars
              Row(
                children: List.generate(5, (i) {
                  final starValue = i + 1;
                  return Icon(
                    starValue <= rating
                        ? Icons.star
                        : (starValue - 0.5 <= rating
                            ? Icons.star_half
                            : Icons.star_border),
                    color: Colors.amber,
                    size: 18,
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                '$total ${total == 1 ? 'recensione' : 'recensioni'}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          // Distribution bars
          if (stats != null && stats.totalReviews > 0)
            Expanded(
              child: Column(
                children: List.generate(5, (i) {
                  final star = 5 - i;
                  final count = stats.distribution[star] ?? 0;
                  final percent = stats.totalReviews > 0
                      ? count / stats.totalReviews
                      : 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text('$star', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(width: 4),
                        const Icon(Icons.star, size: 12, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: percent,
                              backgroundColor: Colors.grey[200],
                              valueColor: const AlwaysStoppedAnimation(Colors.amber),
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 24,
                          child: Text(
                            '$count',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  // ============================
  // WRITE REVIEW
  // ============================

  Widget _buildWriteReviewButton(PetBusinessModel biz) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return InkWell(
      onTap: () => _showWriteReviewDialog(biz),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _categoryColor(biz.category).withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _categoryColor(biz.category).withOpacity(0.2)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: user.photoURL != null
                  ? NetworkImage(user.photoURL!)
                  : null,
              backgroundColor: _categoryColor(biz.category).withOpacity(0.2),
              child: user.photoURL == null
                  ? Icon(Icons.person, size: 20, color: _categoryColor(biz.category))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Scrivi una recensione...',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 15,
                ),
              ),
            ),
            Row(
              children: List.generate(5, (i) => Icon(
                Icons.star_border,
                color: Colors.grey[400],
                size: 22,
              )),
            ),
          ],
        ),
      ),
    );
  }

  void _showWriteReviewDialog(PetBusinessModel biz) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    double selectedRating = 0;
    final commentController = TextEditingController();
    String? errorMessage;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.surfaceDark
                  : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
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

                  // Title
                  Text(
                    'La tua recensione',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    biz.name,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Star rating
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (i) {
                        final star = i + 1;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedRating = star.toDouble()),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              star <= selectedRating ? Icons.star : Icons.star_border,
                              color: star <= selectedRating ? Colors.amber : Colors.grey[400],
                              size: 40,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      selectedRating == 0
                          ? 'Tocca per valutare'
                          : _ratingLabel(selectedRating),
                      style: TextStyle(
                        fontSize: 14,
                        color: selectedRating == 0 ? Colors.grey[400] : Colors.amber[700],
                        fontWeight: selectedRating == 0 ? FontWeight.normal : FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Comment field
                  TextField(
                    controller: commentController,
                    maxLines: 4,
                    maxLength: 1000,
                    decoration: InputDecoration(
                      hintText: biz.category == PetBusinessCategory.dogPark
                          ? 'Come ti sei trovato in questa area cani? È pulita, sicura, attrezzata?'
                          : biz.category == PetBusinessCategory.petFriendlyBeach
                              ? 'Com\'è questa spiaggia? È adatta ai cani? È pulita e accessibile?'
                              : biz.category == PetBusinessCategory.petFriendlyBathhouse
                                  ? 'Com\'è questo stabilimento? È attrezzato per i cani? Servizi e pulizia?'
                                  : 'Descrivi la tua esperienza...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _categoryColor(biz.category)),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[50],
                    ),
                  ),

                  // Error message
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : () async {
                        if (selectedRating == 0) {
                          setDialogState(() => errorMessage = 'Seleziona una valutazione.');
                          return;
                        }
                        if (commentController.text.trim().isEmpty) {
                          setDialogState(() => errorMessage = 'Scrivi un commento.');
                          return;
                        }

                        setDialogState(() {
                          isSubmitting = true;
                          errorMessage = null;
                        });

                        final result = await ref.read(reviewServiceProvider).submitPetBusinessReview(
                          businessId: biz.id,
                          authorId: user.uid,
                          authorName: user.displayName ?? 'Utente',
                          authorPhotoUrl: user.photoURL,
                          rating: selectedRating,
                          comment: commentController.text,
                        );

                        if (!mounted) return;

                        if (result.success) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(result.message),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                          _loadReviewStats(); // Refresh
                        } else {
                          setDialogState(() {
                            isSubmitting = false;
                            errorMessage = result.message;
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _categoryColor(biz.category),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Pubblica recensione', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    ),
                  ),

                  // Moderation notice
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      '🛡️ Le recensioni sono controllate per rispettare le linee guida della community.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================
  // REVIEWS LIST
  // ============================

  Widget _buildReviewsList(PetBusinessModel biz) {
    final reviewService = ref.read(reviewServiceProvider);

    return StreamBuilder<List<ReviewModel>>(
      stream: reviewService.getPetBusinessReviewsStream(biz.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        final reviews = snapshot.data ?? [];
        if (reviews.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.rate_review_outlined, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text(
                    'Nessuna recensione ancora',
                    style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sii il primo a lasciare una recensione!',
                    style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: reviews.map((review) => _buildReviewTile(review, biz)).toList(),
        );
      },
    );
  }

  Widget _buildReviewTile(ReviewModel review, PetBusinessModel biz) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwn = currentUser?.uid == review.authorId;
    final timeAgo = _timeAgo(review.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: review.authorPhotoUrl != null
                    ? NetworkImage(review.authorPhotoUrl!)
                    : null,
                backgroundColor: _categoryColor(biz.category).withOpacity(0.15),
                child: review.authorPhotoUrl == null
                    ? Text(
                        review.authorName.isNotEmpty ? review.authorName[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _categoryColor(biz.category),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.authorName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      timeAgo,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              // Stars
              Row(
                children: List.generate(5, (i) => Icon(
                  i < review.rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 16,
                )),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Comment
          Text(
            review.comment,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              height: 1.4,
            ),
          ),

          const SizedBox(height: 8),

          // Actions row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Report button (not for own reviews)
              if (!isOwn)
                TextButton.icon(
                  onPressed: () => _reportReview(review, biz),
                  icon: Icon(Icons.flag_outlined, size: 16, color: Colors.grey[400]),
                  label: Text('Segnala', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              // Delete button (own reviews only)
              if (isOwn)
                TextButton.icon(
                  onPressed: () => _deleteReview(review, biz),
                  icon: Icon(Icons.delete_outline, size: 16, color: Colors.red[300]),
                  label: Text('Elimina', style: TextStyle(fontSize: 12, color: Colors.red[300])),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================
  // ACTIONS
  // ============================

  Future<void> _reportReview(ReviewModel review, PetBusinessModel biz) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Segnala recensione'),
        content: const Text(
          'Vuoi segnalare questa recensione come inappropriata? '
          'Il nostro team la esaminerà.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Segnala', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await ref.read(reviewServiceProvider).reportReview(
      businessId: biz.id,
      reviewId: review.id,
      reportingUserId: user.uid,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _deleteReview(ReviewModel review, PetBusinessModel biz) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Elimina recensione'),
        content: const Text('Sei sicuro di voler eliminare la tua recensione?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Elimina', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await ref.read(reviewServiceProvider).deletePetBusinessReview(
      businessId: biz.id,
      reviewId: review.id,
      requestingUserId: user.uid,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Recensione eliminata.' : 'Errore durante l\'eliminazione.'),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      if (success) _loadReviewStats();
    }
  }

  // ============================
  // CLAIM BUSINESS
  // ============================

  Widget _buildClaimBusinessCTA(PetBusinessModel biz, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: GestureDetector(
        onTap: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
            settings: const RouteSettings(name: 'claim_business'),
              builder: (_) => ClaimBusinessScreen(business: biz),
            ),
          );
          if (result == true) _loadClaimStatus();
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF6C63FF).withOpacity(0.9),
                const Color(0xFF4A42D1).withOpacity(0.95),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.storefront, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sei il proprietario?',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Riscatta questa pagina e gestisci la tua attività',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClaimStatusBanner(String status) {
    final isPending = status == 'pending';
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isPending
              ? Colors.orange.withOpacity(0.08)
              : Colors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPending
                ? Colors.orange.withOpacity(0.3)
                : Colors.red.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isPending ? Icons.hourglass_top : Icons.cancel_outlined,
              color: isPending ? Colors.orange : Colors.red,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPending
                        ? 'Richiesta in fase di verifica'
                        : 'Richiesta non approvata',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isPending ? Colors.orange[800] : Colors.red[700],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPending
                        ? 'Il nostro team sta verificando i tuoi documenti (24-48h)'
                        : 'La richiesta non è stata approvata. Puoi riprovare con informazioni diverse.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================
  // UI HELPERS
  // ============================

  Widget _buildBadge(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({required bool isDark, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoTile(IconData icon, String text, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[600], size: 22),
      title: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: onTap != null ? AppColors.primary : null,
        ),
      ),
      onTap: onTap,
      dense: true,
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  String _ratingLabel(double rating) {
    if (rating <= 1) return 'Pessimo';
    if (rating <= 2) return 'Scarso';
    if (rating <= 3) return 'Nella media';
    if (rating <= 4) return 'Buono';
    return 'Eccellente';
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Adesso';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min fa';
    if (diff.inHours < 24) return '${diff.inHours} ore fa';
    if (diff.inDays < 7) return '${diff.inDays} giorni fa';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} settimane fa';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} mesi fa';
    return '${(diff.inDays / 365).floor()} anni fa';
  }

  Color _categoryColor(PetBusinessCategory category) {
    switch (category) {
      case PetBusinessCategory.vetClinic:
        return const Color(0xFFE53935);
      case PetBusinessCategory.petShop:
        return const Color(0xFF00897B);
      case PetBusinessCategory.groomer:
        return const Color(0xFF8E24AA);
      case PetBusinessCategory.petSitter:
        return const Color(0xFF1E88E5);
      case PetBusinessCategory.dogTrainer:
        return const Color(0xFFF4511E);
      case PetBusinessCategory.petHotel:
        return const Color(0xFF3949AB);
      case PetBusinessCategory.petFriendlyCafe:
        return const Color(0xFF6D4C41);
      case PetBusinessCategory.petPharmacy:
        return const Color(0xFF00ACC1);
      case PetBusinessCategory.dogPark:
        return const Color(0xFF43A047);
      case PetBusinessCategory.petFriendlyBeach:
        return const Color(0xFFFFB300);
      case PetBusinessCategory.petFriendlyBathhouse:
        return const Color(0xFFFF8F00);
      case PetBusinessCategory.other:
        return const Color(0xFF757575);
    }
  }
}
