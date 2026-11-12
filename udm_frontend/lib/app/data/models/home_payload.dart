import 'article.dart';
import 'devotional.dart';
import 'memory_verse.dart';
import 'resource_topic.dart';

/// Server-curated dashboard. `fromCache` is set locally when the app had to fall
/// back to the last downloaded payload, so the UI can label it as offline copy.
/// `contentVersion` is the server's change stamp taken when this copy was saved:
/// a copy whose number no longer matches is what tells a screen to refetch the
/// moment the network answers again.
class HomePayload {
  const HomePayload({
    required this.greeting,
    required this.articles,
    this.memoryVerse,
    this.devotion,
    this.resources = const [],
    this.serverTime,
    this.cachedAt,
    this.fromCache = false,
    this.contentVersion,
  });

  final String greeting;
  final MemoryVerse? memoryVerse;
  final Devotional? devotion;
  final List<Article> articles;

  /// The "Find resources on" list, in the order the ministry put it in. It
  /// travels with the dashboard so home needs one request for every section.
  final List<ResourceTopic> resources;
  final DateTime? serverTime;
  final DateTime? cachedAt;
  final bool fromCache;
  final int? contentVersion;

  bool get isEmpty =>
      memoryVerse == null && devotion == null && articles.isEmpty && resources.isEmpty;

  factory HomePayload.fromJson(Map<String, dynamic> json) => HomePayload(
        greeting: json['greeting'] as String? ?? '',
        memoryVerse: _map(json['memory_verse'], MemoryVerse.fromJson),
        devotion: _map(json['devotion'], Devotional.fromJson),
        articles: (json['articles'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(Article.fromJson)
            .toList(),
        resources: (json['resources'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ResourceTopic.fromJson)
            .toList(),
        serverTime: json['server_time'] == null ? null : DateTime.tryParse(json['server_time'] as String),
        cachedAt: json['cached_at'] == null ? null : DateTime.tryParse(json['cached_at'] as String),
        fromCache: json['from_cache'] as bool? ?? false,
        contentVersion: (json['content_version'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'greeting': greeting,
        'memory_verse': memoryVerse?.toJson(),
        'devotion': devotion?.toJson(),
        'articles': articles.map((article) => article.toJson()).toList(),
        'resources': resources.map((topic) => topic.toJson()).toList(),
        'server_time': serverTime?.toIso8601String(),
        'cached_at': cachedAt?.toIso8601String(),
        'from_cache': fromCache,
        'content_version': contentVersion,
      };

  /// The dashboard with one section replaced. A private action — marking the
  /// verse memorized — belongs to a single card, and refetching the whole
  /// screen to update it would flash every other card.
  HomePayload copyWith({MemoryVerse? memoryVerse}) => HomePayload(
        greeting: greeting,
        memoryVerse: memoryVerse ?? this.memoryVerse,
        devotion: devotion,
        articles: articles,
        resources: resources,
        serverTime: serverTime,
        cachedAt: cachedAt,
        fromCache: fromCache,
        contentVersion: contentVersion,
      );

  HomePayload withCacheStamp(DateTime moment, {int? version}) => HomePayload(
        greeting: greeting,
        memoryVerse: memoryVerse,
        devotion: devotion,
        articles: articles,
        resources: resources,
        serverTime: serverTime,
        cachedAt: moment,
        contentVersion: version,
      );

  HomePayload asCached() => HomePayload(
        greeting: greeting,
        memoryVerse: memoryVerse,
        devotion: devotion,
        articles: articles,
        resources: resources,
        serverTime: serverTime,
        cachedAt: cachedAt,
        fromCache: true,
        contentVersion: contentVersion,
      );

  static T? _map<T>(Object? raw, T Function(Map<String, dynamic>) build) =>
      raw is Map<String, dynamic> ? build(raw) : null;
}
