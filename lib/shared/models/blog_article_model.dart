/// Model representing a blog article from dogzn.com
class BlogArticleModel {
  final String slug;
  final String title;
  final String description;
  final String category;
  final String author;
  final DateTime pubDate;
  final String? heroImage;
  final String url;

  const BlogArticleModel({
    required this.slug,
    required this.title,
    required this.description,
    required this.category,
    required this.author,
    required this.pubDate,
    this.heroImage,
    required this.url,
  });

  factory BlogArticleModel.fromJson(Map<String, dynamic> json) {
    return BlogArticleModel(
      slug: json['slug'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      author: json['author'] as String,
      pubDate: DateTime.parse(json['pubDate'] as String),
      heroImage: json['heroImage'] as String?,
      url: json['url'] as String,
    );
  }

  /// Icon label for the category
  String get categoryLabel {
    switch (category) {
      case 'salute':
        return 'SALUTE';
      case 'comportamento':
        return 'COMPORTAMENTO';
      case 'sicurezza':
        return 'SICUREZZA';
      case 'quartiere':
        return 'QUARTIERE';
      default:
        return category.toUpperCase();
    }
  }
}
