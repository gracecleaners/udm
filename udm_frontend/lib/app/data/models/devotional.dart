class Devotional {
  const Devotional({
    required this.id,
    required this.title,
    required this.scriptureReference,
    required this.body,
    this.author = '',
    this.excerpt = '',
    this.reflectionQuestions = const [],
    this.application = '',
    this.prayer = '',
    this.memoryScriptureReference = '',
    this.readingMinutes = 5,
    this.publishAt,
  });

  final String id;
  final String title;
  final String scriptureReference;
  final String body;
  final String author;
  final String excerpt;
  final List<String> reflectionQuestions;
  final String application;
  final String prayer;
  final String memoryScriptureReference;
  final int readingMinutes;
  final DateTime? publishAt;

  bool get hasQuestions => reflectionQuestions.isNotEmpty;

  factory Devotional.fromJson(Map<String, dynamic> json) => Devotional(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        scriptureReference: json['scripture_reference'] as String? ?? '',
        body: json['body'] as String? ?? '',
        author: json['author'] as String? ?? '',
        excerpt: json['excerpt'] as String? ?? '',
        reflectionQuestions: (json['reflection_questions'] as List<dynamic>? ?? [])
            .map((item) => item.toString())
            .toList(),
        application: json['application'] as String? ?? '',
        prayer: json['prayer'] as String? ?? '',
        memoryScriptureReference: json['memory_scripture_reference'] as String? ?? '',
        readingMinutes: (json['reading_minutes'] as num?)?.toInt() ?? 5,
        publishAt: json['publish_at'] == null ? null : DateTime.tryParse(json['publish_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'scripture_reference': scriptureReference,
        'body': body,
        'author': author,
        'excerpt': excerpt,
        'reflection_questions': reflectionQuestions,
        'application': application,
        'prayer': prayer,
        'memory_scripture_reference': memoryScriptureReference,
        'reading_minutes': readingMinutes,
        'publish_at': publishAt?.toIso8601String(),
      };
}
