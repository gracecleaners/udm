class Article {
  const Article({
    required this.id,
    required this.title,
    required this.body,
    this.author = '',
    this.category = '',
    this.excerpt = '',
    this.readingMinutes = 4,
    this.imageUrl = '',
    this.publishAt,
  });

  final String id;
  final String title;
  final String body;
  final String author;
  final String category;
  final String excerpt;
  final int readingMinutes;

  /// Artwork the ministry chose for this article. Empty means none was
  /// uploaded, which the cards read as the brand tile, not a broken image.
  final String imageUrl;
  final DateTime? publishAt;

  /// First paragraph, used for list previews.
  String get preview => excerpt.isNotEmpty ? excerpt : body.split('\n\n').first;

  factory Article.fromJson(Map<String, dynamic> json) => Article(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        author: json['author'] as String? ?? '',
        category: json['category'] as String? ?? '',
        excerpt: json['excerpt'] as String? ?? '',
        readingMinutes: (json['reading_minutes'] as num?)?.toInt() ?? 4,
        imageUrl: json['image_url'] as String? ?? '',
        publishAt: json['publish_at'] == null ? null : DateTime.tryParse(json['publish_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'author': author,
        'category': category,
        'excerpt': excerpt,
        'reading_minutes': readingMinutes,
        'image_url': imageUrl,
        'publish_at': publishAt?.toIso8601String(),
      };
}
