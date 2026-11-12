import 'devotion_day.dart';

/// One card in the Devotions grid: a named set of readings, opened day by day.
///
/// `dayCount` is what the server says a student can actually read right now,
/// which is why a series can appear in the grid and still be worth hiding when
/// the count reaches zero.
class DevotionSeries {
  const DevotionSeries({
    required this.id,
    required this.title,
    this.description = '',
    this.coverImageUrl = '',
    this.order = 1,
    this.dayCount = 0,
    this.days = const [],
    this.cachedAt,
    this.fromCache = false,
    this.contentVersion,
  });

  final String id;
  final String title;
  final String description;
  final String coverImageUrl;
  final int order;
  final int dayCount;
  final List<DevotionDay> days;
  final DateTime? cachedAt;
  final bool fromCache;
  final int? contentVersion;

  bool get hasCover => coverImageUrl.isNotEmpty;

  /// Two letters of art for a series the ministry has not photographed yet.
  String get monogram => title
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(2)
      .map((word) => word[0].toUpperCase())
      .join();

  factory DevotionSeries.fromJson(Map<String, dynamic> json) => DevotionSeries(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        coverImageUrl: json['cover_image_url'] as String? ?? '',
        order: (json['order'] as num?)?.toInt() ?? 1,
        dayCount: (json['day_count'] as num?)?.toInt() ?? 0,
        days: (json['days'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(DevotionDay.fromJson)
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
        'cover_image_url': coverImageUrl,
        'order': order,
        'day_count': dayCount,
        'days': days.map((day) => day.toJson()).toList(),
        'cached_at': cachedAt?.toIso8601String(),
        'from_cache': fromCache,
        'content_version': contentVersion,
      };

  DevotionSeries withCacheStamp(DateTime moment, {int? version}) => DevotionSeries(
        id: id,
        title: title,
        description: description,
        coverImageUrl: coverImageUrl,
        order: order,
        dayCount: dayCount,
        days: days,
        cachedAt: moment,
        contentVersion: version,
      );

  DevotionSeries asCached() => DevotionSeries(
        id: id,
        title: title,
        description: description,
        coverImageUrl: coverImageUrl,
        order: order,
        dayCount: dayCount,
        days: days,
        cachedAt: cachedAt,
        fromCache: true,
        contentVersion: contentVersion,
      );
}
