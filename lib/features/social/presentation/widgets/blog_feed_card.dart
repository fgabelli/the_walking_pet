import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/blog_article_model.dart';

/// Card that displays a blog article as an official DOGZN post in the feed.
/// Styled to look like a social post from the brand account.
class BlogFeedCard extends ConsumerWidget {
  final BlogArticleModel article;
  const BlogFeedCard({super.key, required this.article});

  Color _categoryColor(String category) {
    switch (category) {
      case 'salute':
        return const Color(0xFF2E7D32); // green
      case 'sicurezza':
        return const Color(0xFFD32F2F); // red
      case 'comportamento':
        return const Color(0xFF1565C0); // blue
      case 'quartiere':
        return const Color(0xFFF57C00); // orange
      default:
        return AppColors.accent;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'salute':
        return Icons.medical_services_outlined;
      case 'sicurezza':
        return Icons.shield_outlined;
      case 'comportamento':
        return Icons.pets;
      case 'quartiere':
        return Icons.location_on_outlined;
      default:
        return Icons.auto_stories_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catColor = _categoryColor(article.category);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── HEADER: DOGZN avatar + name + verified + "Consiglio" pill ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                // DOGZN avatar
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                  child: const Center(
                    child: Icon(Icons.pets, color: AppColors.accent, size: 18),
                  ),
                ),
                const SizedBox(width: 10),
                // Name + verified
                const Text(
                  'DOGZN',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.verified, color: Color(0xFF1DA1F2), size: 16),
                const SizedBox(width: 8),
                // "Consiglio" pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Consiglio',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── HERO IMAGE ──
          if (article.heroImage != null)
            Image.network(
              article.heroImage!,
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 220,
                color: AppColors.surfaceVariant,
                child: const Center(
                  child: Icon(Icons.auto_stories, size: 48, color: AppColors.textTertiary),
                ),
              ),
            ),

          // ── CATEGORY BADGE ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                Icon(_categoryIcon(article.category), size: 16, color: catColor),
                const SizedBox(width: 6),
                Text(
                  article.categoryLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: catColor,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          // ── TITLE ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Text(
              article.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.25,
              ),
            ),
          ),

          // ── DESCRIPTION ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child: Text(
              article.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),

          // ── CTA BUTTON ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            child: GestureDetector(
              onTap: () => _openArticle(article.url),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A2342),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Leggi l\'articolo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFFFFFF),
                        letterSpacing: 0.3,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20, color: Color(0xFFFFFFFF)),
                  ],
                ),
              ),
            ),
          ),

          // Separator
          Divider(height: 1, color: Colors.grey.shade200),
        ],
      ),
    );
  }

  /// Opens the article URL in the system's in-app browser
  Future<void> _openArticle(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    }
  }
}
