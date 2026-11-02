import 'article.dart';
import 'devotional.dart';
import 'featured_verse.dart';

/// Server-curated dashboard. `fromCache` is set locally when the app had to fall
/// back to the last downloaded payload, so the UI can label it as offline copy.
class HomePayload {
  const HomePayload({
    required this.greeting,
    required this.articles,
    this.verse,
    this.devotion,
    this.serverTime,
    this.cachedAt,
    this.fromCache = false,
  });

  final String greeting;
  final FeaturedVerse? verse;
  final Devotional? devotion;
  final List<Article> articles;
  final DateTime? serverTime;
  final DateTime? cachedAt;
  final bool fromCache;

  bool get isEmpty => verse == null && devotion == null && articles.isEmpty;

  factory HomePayload.fromJson(Map<String, dynamic> json) => HomePayload(
        greeting: json['greeting'] as String? ?? '',
        verse: _map(json['verse'], FeaturedVerse.fromJson),
        devotion: _map(json['devotion'], Devotional.fromJson),
        articles: (json['articles'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(Article.fromJson)
            .toList(),
        serverTime: json['server_time'] == null ? null : DateTime.tryParse(json['server_time'] as String),
        cachedAt: json['cached_at'] == null ? null : DateTime.tryParse(json['cached_at'] as String),
        fromCache: json['from_cache'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'greeting': greeting,
        'verse': verse?.toJson(),
        'devotion': devotion?.toJson(),
        'articles': articles.map((article) => article.toJson()).toList(),
        'server_time': serverTime?.toIso8601String(),
        'cached_at': cachedAt?.toIso8601String(),
        'from_cache': fromCache,
      };

  HomePayload withCacheStamp(DateTime moment) => HomePayload(
        greeting: greeting,
        verse: verse,
        devotion: devotion,
        articles: articles,
        serverTime: serverTime,
        cachedAt: moment,
        fromCache: false,
      );

  HomePayload asCached() => HomePayload(
        greeting: greeting,
        verse: verse,
        devotion: devotion,
        articles: articles,
        serverTime: serverTime,
        cachedAt: cachedAt,
        fromCache: true,
      );

  static T? _map<T>(Object? raw, T Function(Map<String, dynamic>) build) =>
      raw is Map<String, dynamic> ? build(raw) : null;
}
