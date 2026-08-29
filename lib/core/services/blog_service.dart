import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../shared/models/blog_article_model.dart';

/// Provider for the blog service
final blogServiceProvider = Provider<BlogService>((ref) => BlogService());

/// Service that fetches and caches blog articles from dogzn.com
class BlogService {
  static const _feedUrl = 'https://dogzn.com/blog/feed.json';
  static const _cacheDuration = Duration(hours: 6);

  List<BlogArticleModel>? _cachedArticles;
  DateTime? _lastFetch;

  /// Returns cached articles or fetches fresh ones if cache is stale.
  /// Returns empty list on error (graceful degradation).
  Future<List<BlogArticleModel>> getArticles({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedArticles != null && _lastFetch != null) {
      if (DateTime.now().difference(_lastFetch!) < _cacheDuration) {
        return _cachedArticles!;
      }
    }

    try {
      final response = await http
          .get(Uri.parse(_feedUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
        _cachedArticles = json
            .map((item) =>
                BlogArticleModel.fromJson(item as Map<String, dynamic>))
            .toList();
        _lastFetch = DateTime.now();
        return _cachedArticles!;
      }
    } catch (_) {
      // Graceful degradation: return cached data if available, otherwise empty
    }

    return _cachedArticles ?? [];
  }
}
