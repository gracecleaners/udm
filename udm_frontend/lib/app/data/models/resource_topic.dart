import 'resource_step.dart';

/// One row of the home "Find resources on" list: a question a student asks,
/// opened step by step.
///
/// `stepCount` is what the server says is readable right now, which is why a
/// guide can be published and still be absent from the list — the app never
/// renders a row that opens on nothing.
class ResourceTopic {
  const ResourceTopic({
    required this.id,
    required this.title,
    this.summary = '',
    this.imageUrl = '',
    this.order = 1,
    this.stepCount = 0,
    this.stepsCompleted = 0,
    this.steps = const [],
    this.cachedAt,
    this.fromCache = false,
    this.contentVersion,
  });

  final String id;
  final String title;
  final String summary;
  final String imageUrl;
  final int order;
  final int stepCount;

  /// How many of those steps this student has finished, counted by the server
  /// against the same live rows `stepCount` promises. Zero for anybody who has
  /// not started and for a visitor with no account at all.
  final int stepsCompleted;
  final List<ResourceStep> steps;
  final DateTime? cachedAt;
  final bool fromCache;
  final int? contentVersion;

  double get fractionComplete =>
      stepCount <= 0 ? 0 : (stepsCompleted / stepCount).clamp(0.0, 1.0);

  /// Two letters for the row badge; the guides are named, not photographed.
  String get monogram => title
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(2)
      .map((word) => word[0].toUpperCase())
      .join();

  factory ResourceTopic.fromJson(Map<String, dynamic> json) => ResourceTopic(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        imageUrl: json['image_url'] as String? ?? '',
        order: (json['order'] as num?)?.toInt() ?? 1,
        stepCount: (json['step_count'] as num?)?.toInt() ?? 0,
        stepsCompleted: (json['steps_completed'] as num?)?.toInt() ?? 0,
        steps: (json['steps'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ResourceStep.fromJson)
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
        'summary': summary,
        'image_url': imageUrl,
        'order': order,
        'step_count': stepCount,
        'steps_completed': stepsCompleted,
        'steps': steps.map((step) => step.toJson()).toList(),
        'cached_at': cachedAt?.toIso8601String(),
        'from_cache': fromCache,
        'content_version': contentVersion,
      };

  ResourceTopic withCacheStamp(DateTime moment, {int? version}) => ResourceTopic(
        id: id,
        title: title,
        summary: summary,
        imageUrl: imageUrl,
        order: order,
        stepCount: stepCount,
        stepsCompleted: stepsCompleted,
        steps: steps,
        cachedAt: moment,
        contentVersion: version,
      );

  ResourceTopic asCached() => ResourceTopic(
        id: id,
        title: title,
        summary: summary,
        imageUrl: imageUrl,
        order: order,
        stepCount: stepCount,
        stepsCompleted: stepsCompleted,
        steps: steps,
        cachedAt: cachedAt,
        fromCache: true,
        contentVersion: contentVersion,
      );
}
