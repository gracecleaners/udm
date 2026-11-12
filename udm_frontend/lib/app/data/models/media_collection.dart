import 'media_item.dart';

/// One shelf in the Learn tab: a named series of recordings the ministry
/// publishes together, such as SOMA, Uliza or the podcast.
///
/// `itemCount` is what the server says a student can actually open right now,
/// which is why a shelf can be published and still be absent from the tab —
/// the app never renders a row that opens on nothing.
class MediaCollection {
  const MediaCollection({
    required this.id,
    required this.title,
    this.description = '',
    this.order = 1,
    this.imageUrl = '',
    this.itemCount = 0,
    this.items = const [],
    this.cachedAt,
    this.fromCache = false,
    this.contentVersion,
  });

  final String id;
  final String title;
  final String description;
  final int order;
  final String imageUrl;
  final int itemCount;
  final List<MediaItem> items;
  final DateTime? cachedAt;
  final bool fromCache;
  final int? contentVersion;

  bool get hasArt => imageUrl.isNotEmpty;

  /// The shelf art belongs to the ministry, so a shelf can exist without a
  /// picture. Its own name is what the app shows instead of a broken box.
  String get monogram => title
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(2)
      .map((word) => word[0].toUpperCase())
      .join();

  factory MediaCollection.fromJson(Map<String, dynamic> json) => MediaCollection(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        order: (json['order'] as num?)?.toInt() ?? 1,
        imageUrl: json['image_url'] as String? ?? '',
        itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
        items: (json['items'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(MediaItem.fromJson)
            .toList(),
        cachedAt: json['cached_at'] == null
            ? null
            : DateTime.tryParse(json['cached_at'] as String),
        fromCache: json['from_cache'] as bool? ?? false,
        contentVersion: (json['content_version'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'order': order,
        'image_url': imageUrl,
        'item_count': itemCount,
        'items': items.map((item) => item.toJson()).toList(),
        'cached_at': cachedAt?.toIso8601String(),
        'from_cache': fromCache,
        'content_version': contentVersion,
      };

  MediaCollection withCacheStamp(DateTime moment, {int? version}) =>
      copyWith(cachedAt: moment, contentVersion: version);

  MediaCollection asCached() => copyWith(fromCache: true);

  MediaCollection copyWith({
    String? id,
    String? title,
    String? description,
    int? order,
    String? imageUrl,
    int? itemCount,
    List<MediaItem>? items,
    DateTime? cachedAt,
    bool? fromCache,
    int? contentVersion,
  }) => MediaCollection(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    order: order ?? this.order,
    imageUrl: imageUrl ?? this.imageUrl,
    itemCount: itemCount ?? this.itemCount,
    items: items ?? this.items,
    cachedAt: cachedAt ?? this.cachedAt,
    fromCache: fromCache ?? this.fromCache,
    contentVersion: contentVersion ?? this.contentVersion,
  );
}
