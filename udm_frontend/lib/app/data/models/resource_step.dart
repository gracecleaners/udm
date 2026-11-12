/// One part of a guided resource: what the topic teaches, the verse it stands
/// on, and the video the ministry chose to attach.
///
/// The same shape comes back from a topic page (no `body`, enough to choose)
/// and from the step itself (`body`, `videoUrl` and the guide it belongs to), so
/// one model reads both and a row never pretends to hold a passage it was not
/// sent.
class ResourceStep {
  const ResourceStep({
    required this.id,
    required this.title,
    this.order,
    this.scriptureReference = '',
    this.excerpt = '',
    this.body = '',
    this.readingMinutes = 3,
    this.videoUrl = '',
    this.topicId = '',
    this.topicTitle = '',
    this.topicStepCount = 0,
  });

  final String id;
  final String title;

  /// Null is the starting point of a guide, and the server sorts it first.
  final int? order;
  final String scriptureReference;
  final String excerpt;
  final String body;
  final int readingMinutes;

  /// Only ever a link the ministry curated; an empty value means the app shows
  /// no video action at all.
  final String videoUrl;
  final String topicId;
  final String topicTitle;

  /// How many steps the guide has right now, so a reader can see that
  /// "Step 2 of 5" is the real position rather than a counted label.
  final int topicStepCount;

  bool get isStartingPoint => order == null;
  bool get hasVideo => videoUrl.isNotEmpty;

  factory ResourceStep.fromJson(Map<String, dynamic> json) {
    final topic = json['topic'];
    return ResourceStep(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      order: (json['order'] as num?)?.toInt(),
      scriptureReference: json['scripture_reference'] as String? ?? '',
      excerpt: json['excerpt'] as String? ?? '',
      body: json['body'] as String? ?? '',
      readingMinutes: (json['reading_minutes'] as num?)?.toInt() ?? 3,
      videoUrl: json['video_url'] as String? ?? '',
      topicId: topic is Map<String, dynamic> ? topic['id'] as String? ?? '' : '',
      topicTitle: topic is Map<String, dynamic> ? topic['title'] as String? ?? '' : '',
      topicStepCount: topic is Map<String, dynamic>
          ? (topic['step_count'] as num?)?.toInt() ?? 0
          : 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'order': order,
        'scripture_reference': scriptureReference,
        'excerpt': excerpt,
        'body': body,
        'reading_minutes': readingMinutes,
        'video_url': videoUrl,
        'topic': {
          if (topicId.isNotEmpty) 'id': topicId,
          if (topicTitle.isNotEmpty) 'title': topicTitle,
          'step_count': topicStepCount,
        },
      };
}
